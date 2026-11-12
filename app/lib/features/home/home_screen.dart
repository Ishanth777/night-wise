import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../data/routes/route_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/night_map.dart';
import '../../widgets/nw_kit.dart';
import '../../widgets/nw_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _locating = false;
  bool _finding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLocation());
  }

  Future<void> _bootstrapLocation() async {
    if (ref.read(originProvider) != null) return;
    final last = await ref.read(locationServiceProvider).lastKnown();
    if (!mounted || last == null) return;
    if (!AppConfig.inServiceArea(last.lat, last.lng)) return;
    if (ref.read(originProvider) == null) {
      ref.read(originProvider.notifier).state = last;
    }
  }

  Future<void> _acquireLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final position = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) {
      _setError('Location unavailable. Allow access in your browser, or start from the map centre.');
      return;
    }
    if (!AppConfig.inServiceArea(position.lat, position.lng)) {
      _setError('You are outside the Bengaluru service area. NightWise is Bengaluru-only for now.');
      return;
    }
    ref.read(originProvider.notifier).state = position;
    _snack('Start point set to your current location.');
  }

  void _setError(String message) {
    setState(() => _error = message);
    _snack(message);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setDestination(PlaceResult place) {
    setState(() => _error = null);
    ref.read(destinationProvider.notifier).state = place;
  }

  void _swapEndpoints() {
    final destination = ref.read(destinationProvider);
    final origin = ref.read(originProvider) ?? kDefaultCenter;
    if (destination == null) {
      _snack('Choose a destination before swapping.');
      return;
    }
    ref.read(originProvider.notifier).state = destination.point;
    _setDestination(PlaceResult(
      id: 'pin_${origin.lat}_${origin.lng}',
      name: 'Previous start',
      lat: origin.lat,
      lng: origin.lng,
    ));
  }

  Future<void> _openStartSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NwSheet(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Set start point', style: NwText.h2)),
                NwIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  size: 38,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Your start point is only used for this route request.',
              style: NwText.bodyMuted,
            ),
            const SizedBox(height: 18),
            _SheetOption(
              icon: Icons.my_location_rounded,
              title: 'Use my current location',
              subtitle: 'Asks for location permission once',
              highlighted: true,
              onTap: () => Navigator.of(sheetContext).pop('gps'),
            ),
            const SizedBox(height: 9),
            _SheetOption(
              icon: Icons.location_city_outlined,
              title: 'Bengaluru map centre',
              subtitle: 'MG Road area · ${kDefaultCenter.lat.toStringAsFixed(4)}, '
                  '${kDefaultCenter.lng.toStringAsFixed(4)}',
              onTap: () => Navigator.of(sheetContext).pop('centre'),
            ),
            const SizedBox(height: 9),
            _SheetOption(
              icon: Icons.touch_app_outlined,
              title: 'Tap the map',
              subtitle: 'Close this panel, then tap anywhere to drop a pin',
              onTap: () => Navigator.of(sheetContext).pop('map'),
            ),
            const SizedBox(height: 10),
            const NwDataNote(
              text: 'NightWise is Bengaluru-only. Points outside the mapped area '
                  'are rejected rather than approximated.',
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case 'gps':
        await _acquireLocation();
      case 'centre':
        ref.read(originProvider.notifier).state = kDefaultCenter;
        _snack('Start point set to the Bengaluru map centre.');
      case 'map':
        _snack('Tap the map to drop your start point.');
    }
  }

  Future<void> _pickDeparture() async {
    final current = ref.read(departureTimeProvider);
    final now = DateTime.now();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NwSheet(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('When are you leaving?', style: NwText.h2)),
                NwIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  size: 38,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Lighting, shop hours and footfall signals are evaluated for this time.',
              style: NwText.bodyMuted,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [
                  ('Now', 0),
                  ('In 30 min', 30),
                  ('In 1 hour', 60),
                  ('In 2 hours', 120),
                ])
                  _TimeChoice(
                    label: option.$1,
                    time: now.add(Duration(minutes: option.$2)),
                    selected: current
                            .difference(now.add(Duration(minutes: option.$2)))
                            .inMinutes
                            .abs() <
                        2,
                    onTap: () => Navigator.of(sheetContext).pop('quick:${option.$2}'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            NwActionButton(
              label: 'Choose an exact time',
              icon: Icons.schedule_rounded,
              dark: false,
              onPressed: () => Navigator.of(sheetContext).pop('custom'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'custom') {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
        helpText: 'When are you leaving?',
      );
      if (picked == null || !mounted) return;
      var candidate = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      if (candidate.isBefore(now.subtract(const Duration(minutes: 1)))) {
        candidate = candidate.add(const Duration(days: 1));
      }
      ref.read(departureTimeProvider.notifier).state = candidate;
      return;
    }
    final minutes = int.parse(choice.split(':')[1]);
    ref.read(departureTimeProvider.notifier).state = now.add(Duration(minutes: minutes));
  }

  void _findRoutes() {
    final destination = ref.read(destinationProvider);
    if (destination == null) {
      _setError('Choose a destination to compare night-time routes.');
      return;
    }
    final origin = ref.read(originProvider) ?? kDefaultCenter;
    if (!AppConfig.inServiceArea(origin.lat, origin.lng) ||
        !AppConfig.inServiceArea(destination.lat, destination.lng)) {
      _setError('Both points must be inside the mapped Bengaluru area.');
      return;
    }
    if (origin == destination.point) {
      _setError('Start and destination are the same point. Pick another destination.');
      return;
    }
    final departure = ref.read(departureTimeProvider);
    final normalized = departure.isAfter(DateTime.now())
        ? departure
        : DateTime.now().add(const Duration(minutes: 5));
    ref.read(departureTimeProvider.notifier).state = normalized;
    ref.read(recommendationRequestProvider.notifier).state = RecommendationRequest(
      origin: origin,
      destination: destination.point,
      mode: ref.read(modeProvider),
      vehicleType: ref.read(vehicleTypeProvider),
      departureTime: normalized,
      safetyVsTime: ref.read(safetySliderProvider),
    );
    ref.invalidate(recommendationProvider);
    setState(() {
      _finding = true;
      _error = null;
    });
    context.push('/routes').whenComplete(() {
      if (mounted) setState(() => _finding = false);
    });
  }

  void _showHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => NwSheet(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('How NightWise ranks routes', style: NwText.h2)),
                NwIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  size: 38,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _HowRow(
              icon: Icons.lightbulb_outline,
              title: 'Street lighting',
              body: 'Uses OpenStreetMap lighting tags and road-class priors. No verified '
                  'lamp-post dataset exists for Bengaluru yet, so this signal is '
                  'lower-confidence and labelled as such.',
            ),
            const _HowRow(
              icon: Icons.storefront_outlined,
              title: 'Open businesses',
              body: 'Counts shops and services whose real recorded opening hours cover '
                  'your departure time. Unknown hours are never treated as closed.',
            ),
            const _HowRow(
              icon: Icons.directions_walk,
              title: 'Footfall & activity',
              body: 'Estimated from nearby places and road class, not live crowd data.',
            ),
            const _HowRow(
              icon: Icons.forum_outlined,
              title: 'Community reports',
              body: 'Only moderator-published reports influence scores. Reports are never '
                  'published automatically from a single submission.',
            ),
            const SizedBox(height: 8),
            const NwDataNote(
              text: 'Missing data lowers confidence; it is never replaced with a '
                  'fabricated value. Scores are environmental estimates, not guarantees '
                  'of personal safety.',
              icon: Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(originProvider);
    final destination = ref.watch(destinationProvider);
    final mode = ref.watch(modeProvider);
    final vehicleType = ref.watch(vehicleTypeProvider);
    final slider = ref.watch(safetySliderProvider);
    final departure = ref.watch(departureTimeProvider);
    final start = origin ?? kDefaultCenter;
    final wide = NwBreakpoints.isWide(context);
    final compact = NwBreakpoints.isCompact(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: NightMap(
              center: destination?.point ?? start,
              zoom: 14.2,
              origin: start,
              destination: destination?.point,
              onTap: (point) {
                _setDestination(PlaceResult(
                  id: 'pin_${point.lat}_${point.lng}',
                  name: 'Dropped pin',
                  lat: point.lat,
                  lng: point.lng,
                ));
                _snack('Destination set to the dropped pin.');
              },
            ),
          ),

          // Top chrome
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 14, wide ? 24 : 14, 0),
              child: Row(
                children: [
                  _BrandCapsule(onInfo: _showHowItWorks),
                  const Spacer(),
                  NwIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Use my location',
                    busy: _locating,
                    onPressed: _acquireLocation,
                  ),
                  const SizedBox(width: 8),
                  NwIconButton(
                    icon: Icons.sos_outlined,
                    tooltip: 'Emergency',
                    dark: true,
                    filledColor: NwColors.ink,
                    onPressed: () => context.push('/emergency', extra: start),
                  ),
                  const SizedBox(width: 8),
                  NwIconButton(
                    icon: Icons.person_outline_rounded,
                    tooltip: 'Profile',
                    onPressed: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ),

          // Map-side navigation rail (desktop / tablet)
          if (!compact)
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: wide ? 24 : 14, bottom: 40),
                  child: const NwFloatingRail(current: 'map'),
                ),
              ),
            ),

          // Planner panel
          if (wide)
            Positioned(
              top: 86,
              right: 24,
              bottom: 24,
              width: 408,
              child: _PlannerCard(
                origin: origin,
                destination: destination,
                start: start,
                mode: mode,
                vehicleType: vehicleType,
                slider: slider,
                departure: departure,
                error: _error,
                finding: _finding,
                onStart: _openStartSheet,
                onDestination: () => context.push('/search').then((_) {
                  if (mounted) setState(() => _error = null);
                }),
                onClearDestination: () => ref.read(destinationProvider.notifier).state = null,
                onSwap: _swapEndpoints,
                onMode: (value) => ref.read(modeProvider.notifier).state = value,
                onVehicle: (value) => ref.read(vehicleTypeProvider.notifier).state = value,
                onSlider: (value) => ref.read(safetySliderProvider.notifier).state = value,
                onTime: _pickDeparture,
                onFind: _findRoutes,
                onInfo: _showHowItWorks,
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: NwSheet(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: _PlannerContent(
                      origin: origin,
                      destination: destination,
                      start: start,
                      mode: mode,
                      vehicleType: vehicleType,
                      slider: slider,
                      departure: departure,
                      error: _error,
                      finding: _finding,
                      onStart: _openStartSheet,
                      onDestination: () => context.push('/search').then((_) {
                        if (mounted) setState(() => _error = null);
                      }),
                      onClearDestination: () =>
                          ref.read(destinationProvider.notifier).state = null,
                      onSwap: _swapEndpoints,
                      onMode: (value) => ref.read(modeProvider.notifier).state = value,
                      onVehicle: (value) =>
                          ref.read(vehicleTypeProvider.notifier).state = value,
                      onSlider: (value) => ref.read(safetySliderProvider.notifier).state = value,
                      onTime: _pickDeparture,
                      onFind: _findRoutes,
                      onInfo: _showHowItWorks,
                      dense: true,
                    ),
                  ),
                ),
              ),
            ),

          if (!wide)
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, NwColors.canvas],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- chrome

class _BrandCapsule extends StatelessWidget {
  const _BrandCapsule({required this.onInfo});
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NwColors.panel.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(NwRadii.chip),
      child: InkWell(
        onTap: onInfo,
        borderRadius: BorderRadius.circular(NwRadii.chip),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NwRadii.chip),
            border: Border.all(color: NwColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NwLogo(size: 28),
              const SizedBox(width: 9),
              const NwWordmark(size: 15),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: NwColors.line),
              const SizedBox(width: 10),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: NwColors.accentDeep,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Bengaluru',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NwColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- planner

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.origin,
    required this.destination,
    required this.start,
    required this.mode,
    required this.vehicleType,
    required this.slider,
    required this.departure,
    required this.error,
    required this.finding,
    required this.onStart,
    required this.onDestination,
    required this.onClearDestination,
    required this.onSwap,
    required this.onMode,
    required this.onVehicle,
    required this.onSlider,
    required this.onTime,
    required this.onFind,
    required this.onInfo,
  });

  final LatLngPoint? origin;
  final PlaceResult? destination;
  final LatLngPoint start;
  final String mode;
  final String vehicleType;
  final double slider;
  final DateTime departure;
  final String? error;
  final bool finding;
  final VoidCallback onStart;
  final VoidCallback onDestination;
  final VoidCallback onClearDestination;
  final VoidCallback onSwap;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onVehicle;
  final ValueChanged<double> onSlider;
  final VoidCallback onTime;
  final VoidCallback onFind;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: BorderRadius.circular(NwRadii.sheet),
        border: Border.all(color: NwColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24111410),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NwRadii.sheet),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: _PlannerContent(
            origin: origin,
            destination: destination,
            start: start,
            mode: mode,
            vehicleType: vehicleType,
            slider: slider,
            departure: departure,
            error: error,
            finding: finding,
            onStart: onStart,
            onDestination: onDestination,
            onClearDestination: onClearDestination,
            onSwap: onSwap,
            onMode: onMode,
            onVehicle: onVehicle,
            onSlider: onSlider,
            onTime: onTime,
            onFind: onFind,
            onInfo: onInfo,
          ),
        ),
      ),
    );
  }
}

class _PlannerContent extends StatelessWidget {
  const _PlannerContent({
    required this.origin,
    required this.destination,
    required this.start,
    required this.mode,
    required this.vehicleType,
    required this.slider,
    required this.departure,
    required this.error,
    required this.finding,
    required this.onStart,
    required this.onDestination,
    required this.onClearDestination,
    required this.onSwap,
    required this.onMode,
    required this.onVehicle,
    required this.onSlider,
    required this.onTime,
    required this.onFind,
    required this.onInfo,
    this.dense = false,
  });

  final LatLngPoint? origin;
  final PlaceResult? destination;
  final LatLngPoint start;
  final String mode;
  final String vehicleType;
  final double slider;
  final DateTime departure;
  final String? error;
  final bool finding;
  final VoidCallback onStart;
  final VoidCallback onDestination;
  final VoidCallback onClearDestination;
  final VoidCallback onSwap;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onVehicle;
  final ValueChanged<double> onSlider;
  final VoidCallback onTime;
  final VoidCallback onFind;
  final VoidCallback onInfo;
  final bool dense;

  String get _originLabel {
    if (origin == null) return 'Bengaluru map centre';
    if ((origin!.lat - kDefaultCenter.lat).abs() < 0.00001 &&
        (origin!.lng - kDefaultCenter.lng).abs() < 0.00001) {
      return 'Bengaluru map centre';
    }
    return 'Your start point';
  }

  String get _originSub {
    if (origin == null) return 'MG Road area · tap to change';
    return '${start.lat.toStringAsFixed(4)}, ${start.lng.toStringAsFixed(4)} · tap to change';
  }

  String get _safetyLabel {
    if (slider >= 0.66) return 'Prioritise safety';
    if (slider <= 0.34) return 'Prioritise speed';
    return 'Balanced';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('NIGHT PLAN', style: NwText.eyebrow),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: NwColors.accentDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'BENGALURU',
                        style: NwText.eyebrow.copyWith(color: NwColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Where are you\nheading tonight?',
                    style: dense ? NwText.h1.copyWith(fontSize: 24) : NwText.h1,
                  ),
                ],
              ),
            ),
            NwIconButton(
              icon: Icons.info_outline_rounded,
              tooltip: 'How scoring works',
              size: 38,
              onPressed: onInfo,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Origin / destination card
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            color: NwColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NwColors.line),
          ),
          child: Column(
            children: [
              _EndpointRow(
                icon: Icons.radio_button_checked,
                iconColor: NwColors.ink,
                label: _originLabel,
                subtitle: _originSub,
                onTap: onStart,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 11, right: 4),
                child: Row(
                  children: [
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.only(left: 6),
                      color: NwColors.lineStrong,
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onSwap,
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 15, color: NwColors.textMuted),
                            const SizedBox(width: 3),
                            Text('swap', style: NwText.small.copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _EndpointRow(
                icon: Icons.place_rounded,
                iconColor: NwColors.textMuted,
                label: destination?.name ?? 'Choose a destination',
                subtitle: destination == null
                    ? 'Search a place or tap the map'
                    : '${destination!.lat.toStringAsFixed(4)}, '
                        '${destination!.lng.toStringAsFixed(4)}',
                isPlaceholder: destination == null,
                onTap: onDestination,
                trailing: destination == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear destination',
                        icon: const Icon(Icons.close_rounded, size: 17),
                        onPressed: onClearDestination,
                        visualDensity: VisualDensity.compact,
                      ),
              ),
            ],
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: NwColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: NwColors.danger),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.4,
                      color: NwColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),
        NwSegmented(
          value: mode,
          onChanged: onMode,
          compact: dense,
          options: const [
            NwSegmentOption('walk', 'Walking', icon: Icons.directions_walk_rounded),
            NwSegmentOption('vehicle', 'Driving', icon: Icons.directions_car_filled_outlined),
          ],
        ),
        if (mode == 'vehicle') ...[
          const SizedBox(height: 9),
          Row(
            children: [
              for (final option in const [
                ('car', 'Car', Icons.directions_car_outlined),
                ('two_wheeler', 'Two-wheeler', Icons.two_wheeler_outlined),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: NwPill(
                    label: option.$2,
                    icon: option.$3,
                    background: vehicleType == option.$1 ? NwColors.accent : NwColors.panel,
                    color: NwColors.ink,
                    onTap: () => onVehicle(option.$1),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 15, color: NwColors.textMuted),
            const SizedBox(width: 7),
            Text(
              'Leave ${DateFormat('HH:mm').format(departure)}'
              '${DateFormat('d MMM').format(departure) == DateFormat('d MMM').format(DateTime.now()) ? ' · today' : ' · ${DateFormat('d MMM').format(departure)}'}',
              style: NwText.label,
            ),
            const Spacer(),
            TextButton(
              onPressed: onTime,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 15, color: NwColors.textMuted),
            const SizedBox(width: 7),
            const Text('Safety vs time', style: NwText.label),
            const Spacer(),
            Text(
              _safetyLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: NwColors.ink,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: NwColors.ink,
            inactiveTrackColor: NwColors.line,
            thumbColor: NwColors.accent,
            overlayColor: NwColors.accent.withValues(alpha: 0.2),
            trackHeight: 5,
          ),
          child: Slider(
            value: slider,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: onSlider,
            semanticFormatterCallback: (value) => 'Safety ${(value * 100).round()} percent',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FASTER', style: NwText.eyebrow.copyWith(fontSize: 9.5)),
              Text('SAFER', style: NwText.eyebrow.copyWith(fontSize: 9.5)),
            ],
          ),
        ),

        SizedBox(height: dense ? 12 : 16),
        NwActionButton(
          label: 'Find safer routes',
          icon: Icons.arrow_forward_rounded,
          busy: finding,
          onPressed: onFind,
        ),
        const SizedBox(height: 10),
        const NwDataNote(
          text: 'Ranked from OSM lighting tags, real opening hours and published '
              'community reports. Missing data is labelled, never invented.',
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.isPlaceholder = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: isPlaceholder ? NwColors.textMuted : NwColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NwText.small,
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded, size: 19, color: NwColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? NwColors.accent : NwColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? Colors.transparent : NwColors.line,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: NwColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NwText.label.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: NwText.small),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChoice extends StatelessWidget {
  const _TimeChoice({
    required this.label,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final DateTime time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NwColors.ink : NwColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.transparent : NwColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: selected ? NwColors.onDark : NwColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                DateFormat('HH:mm').format(time),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  color: selected ? NwColors.onDarkMuted : NwColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NwColors.canvas,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: NwColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NwText.label.copyWith(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(body, style: NwText.bodyMuted.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}