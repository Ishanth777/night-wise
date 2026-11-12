import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;

  static const _popular = <(String, String, IconData)>[
    ('MG Road Metro Station', 'MG Road · Bengaluru', Icons.train_outlined),
    ('Koramangala 5th Block', 'Koramangala · Bengaluru', Icons.local_cafe_outlined),
    ('Indiranagar 100 Feet Road', 'Indiranagar · Bengaluru', Icons.restaurant_outlined),
    ('Bengaluru City Railway Station', 'Majestic · Bengaluru', Icons.directions_railway_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final text = value.trim();
    setState(() => _error = null);
    if (text.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () => _search(text));
  }

  Future<void> _search(String text) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(routeRepositoryProvider).searchPlaces(
            text,
            near: ref.read(originProvider),
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = error is AppFailure ? error.message : 'Place search failed.';
      });
    }
  }

  void _select(PlaceResult place) {
    if (!AppConfig.inServiceArea(place.lat, place.lng)) {
      _showSnack('That place is outside the mapped Bengaluru area.');
      return;
    }
    ref.read(destinationProvider.notifier).state = place;
    context.pop();
  }

  Future<void> _enterCoordinates() async {
    final lat = TextEditingController();
    final lng = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter coordinates'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: lat,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '12.9756',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Enter a decimal number';
                  if (parsed < -90 || parsed > 90) return 'Latitude must be −90 to 90';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: lng,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '77.6040',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Enter a decimal number';
                  if (parsed < -180 || parsed > 180) return 'Longitude must be −180 to 180';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Use point'),
          ),
        ],
      ),
    );
    final latValue = double.tryParse(lat.text.trim());
    final lngValue = double.tryParse(lng.text.trim());
    lat.dispose();
    lng.dispose();
    if (done != true || !mounted) return;
    if (latValue == null || lngValue == null) {
      _showSnack('Enter valid decimal coordinates.');
      return;
    }
    if (!AppConfig.inServiceArea(latValue, lngValue)) {
      _showSnack('That point is outside the Bengaluru service area.');
      return;
    }
    _select(PlaceResult(
      id: 'coords_${latValue}_$lngValue',
      name: 'Dropped pin',
      lat: latValue,
      lng: lngValue,
    ));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = NwBreakpoints.isWide(context);
    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                    child: Row(
                      children: [
                        NwIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                          size: 44,
                        ),
                        const Spacer(),
                        const NwWordmark(size: 15),
                        const Spacer(),
                        NwIconButton(
                          icon: Icons.pin_drop_outlined,
                          tooltip: 'Enter coordinates',
                          onPressed: _enterCoordinates,
                          size: 44,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('FIND A PLACE', style: NwText.eyebrow),
                  const SizedBox(height: 6),
                  Text('Where are you going?', style: NwText.h1),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _query,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (value) {
                      final text = value.trim();
                      if (text.length >= 2) _search(text);
                    },
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search a place, street or landmark',
                      prefixIcon: const Icon(Icons.search_rounded, size: 21),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded, size: 19),
                              onPressed: () {
                                _query.clear();
                                _onChanged('');
                                _focus.requestFocus();
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    const SizedBox(height: 2),
                  const SizedBox(height: 8),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return NwErrorState(
        title: 'Search is unavailable',
        message: _error!,
        onRetry: () {
          final text = _query.text.trim();
          if (text.length >= 2) _search(text);
        },
      );
    }
    if (_query.text.trim().length < 2) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          const Text('Popular in Bengaluru', style: NwText.label),
          const SizedBox(height: 10),
          for (final place in _popular)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NwCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () {
                  _query.text = '${place.$1}, Bengaluru';
                  _focus.unfocus();
                  _search(_query.text);
                },
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: NwColors.canvas,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(place.$3, size: 18, color: NwColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NwText.label.copyWith(fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(place.$2, style: NwText.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.north_west_rounded, size: 16, color: NwColors.textMuted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const NwDataNote(
            text: 'Search uses OpenStreetMap place data with Photon/Nominatim '
                'geocoding. You can also drop a pin on the map from the home screen.',
            icon: Icons.travel_explore_rounded,
          ),
        ],
      );
    }
    if (_results.isEmpty && !_loading) {
      return NwEmptyState(
        icon: Icons.location_off_outlined,
        title: 'No places found',
        message: 'Try a landmark, a neighbourhood name, or enter coordinates '
            'directly with the pin button above.',
        action: _enterCoordinates,
        actionLabel: 'Enter coordinates',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final place = _results[index];
        return NwCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _select(place),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NwColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.place_outlined, size: 18, color: NwColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NwText.label.copyWith(fontSize: 13.5, height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}'
                      '${place.type.isEmpty ? '' : ' · ${place.type}'}',
                      style: NwText.small,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: NwColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}