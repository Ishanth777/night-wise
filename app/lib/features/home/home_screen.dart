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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _locating = false;

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
    setState(() => _locating = true);
    final position = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) {
      _snack('Location unavailable. Enable location access or start from the map centre.');
      return;
    }
    if (!AppConfig.inServiceArea(position.lat, position.lng)) {
      _snack('You are outside the Bengaluru service area. NightWise is Bengaluru-only for now.');
      return;
    }
    ref.read(originProvider.notifier).state = position;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openStartSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NwColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Set start point',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: NwColors.primary),
              title: const Text('Use my current location'),
              subtitle: const Text('Requires location permission'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _acquireLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_city, color: NwColors.textMuted),
              title: const Text('Map centre — Bengaluru'),
              subtitle: const Text('MG Road area (default)'),
              onTap: () {
                ref.read(originProvider.notifier).state = kDefaultCenter;
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeparture() async {
    final current = ref.read(departureTimeProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'When are you leaving?',
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (candidate.isBefore(now.subtract(const Duration(minutes: 1)))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    ref.read(departureTimeProvider.notifier).state = candidate;
  }

  void _findRoutes() {
    final destination = ref.read(destinationProvider);
    if (destination == null) {
      _snack('Pick a destination by searching or tapping the map.');
      return;
    }
    final origin = ref.read(originProvider) ?? kDefaultCenter;
    if (!AppConfig.inServiceArea(origin.lat, origin.lng) ||
        !AppConfig.inServiceArea(destination.lat, destination.lng)) {
      _snack('NightWise is Bengaluru-only for now — both points must be inside the mapped area.');
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
    context.push('/routes');
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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NightMap(
              center: destination?.point ?? start,
              zoom: 14.5,
              origin: start,
              destination: destination?.point,
              onTap: (point) {
                ref.read(destinationProvider.notifier).state = PlaceResult(
                  id: 'pin_${point.lat}_${point.lng}',
                  name: 'Dropped pin',
                  lat: point.lat,
                  lng: point.lng,
                );
                _snack('Destination set to dropped pin.');
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _CircleAction(
                    icon: Icons.my_location,
                    busy: _locating,
                    onTap: _acquireLocation,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: NwColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.push('/search'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: NwColors.textMuted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  destination?.name.isNotEmpty == true
                                      ? destination!.name
                                      : 'Where are you going?',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: destination == null
                                        ? NwColors.textMuted
                                        : NwColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: Icons.emergency_outlined,
                    color: NwColors.risky,
                    onTap: () => context.push('/emergency'),
                  ),
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: Icons.person_outline,
                    onTap: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: NwColors.surface.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EndpointRow(
                        icon: Icons.trip_origin,
                        color: NwColors.primary,
                        label: origin == null ? 'Map centre — Bengaluru' : 'Your location',
                        subtitle: origin == null
                            ? 'Tap to use GPS or keep the default'
                            : '${start.lat.toStringAsFixed(4)}, ${start.lng.toStringAsFixed(4)}',
                        onTap: _openStartSheet,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 11),
                        child: SizedBox(
                          height: 14,
                          child: VerticalDivider(
                            width: 2,
                            thickness: 1,
                            color: NwColors.surfaceHigh,
                          ),
                        ),
                      ),
                      _EndpointRow(
                        icon: Icons.place,
                        color: NwColors.risky,
                        label: destination?.name ?? 'Choose a destination',
                        subtitle: destination == null
                            ? 'Search a place or tap the map'
                            : '${destination.lat.toStringAsFixed(4)}, ${destination.lng.toStringAsFixed(4)}',
                        onTap: () => context.push('/search'),
                        trailing: destination == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear destination',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  ref.read(destinationProvider.notifier).state = null;
                                },
                              ),
                      ),
                      const SizedBox(height: 14),
                      _ModeSelector(
                        mode: mode,
                        vehicleType: vehicleType,
                        onMode: (value) {
                          ref.read(modeProvider.notifier).state = value;
                        },
                        onVehicle: (value) {
                          ref.read(vehicleTypeProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text('Safety vs time',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            slider >= 0.66
                                ? 'Prefer safety'
                                : slider <= 0.34
                                    ? 'Prefer speed'
                                    : 'Balanced',
                            style: const TextStyle(
                              color: NwColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: slider,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        activeColor: NwColors.primary,
                        inactiveColor: NwColors.surfaceHigh,
                        onChanged: (value) =>
                            ref.read(safetySliderProvider.notifier).state = value,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: NwColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Leave ${DateFormat('HH:mm').format(departure)}',
                            style: const TextStyle(color: NwColors.textMuted, fontSize: 13),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _pickDeparture,
                            child: const Text('Change time'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        onPressed: _findRoutes,
                        icon: const Icon(Icons.shield_moon_outlined),
                        label: const Text('Find safe routes'),
                      ),
                    ],
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

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NwColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: NwColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.vehicleType,
    required this.onMode,
    required this.onVehicle,
  });

  final String mode;
  final String vehicleType;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onVehicle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: NwColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _modeButton('walk', 'Walking', Icons.directions_walk),
              _modeButton('vehicle', 'Vehicle', Icons.directions_car),
            ],
          ),
        ),
        if (mode == 'vehicle')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Car'),
                  selected: vehicleType == 'car',
                  onSelected: (_) => onVehicle('car'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Two-wheeler'),
                  selected: vehicleType == 'two_wheeler',
                  onSelected: (_) => onVehicle('two_wheeler'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _modeButton(String value, String label, IconData icon) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onMode(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? NwColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? NwColors.night : NwColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? NwColors.night : NwColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.color = NwColors.text,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NwColors.surface.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: NwColors.primary),
                )
              : Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}
