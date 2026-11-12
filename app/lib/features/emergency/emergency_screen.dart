import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key, this.point});

  final LatLngPoint? point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = point ??
        ref.watch(originProvider) ??
        ref.watch(destinationProvider)?.point ??
        kDefaultCenter;
    final async = ref.watch(emergencyProvider(anchor));
    final wide = NwBreakpoints.isWide(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 14, wide ? 0 : 16, 0),
                  child: Row(
                    children: [
                      NwIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        size: 44,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      ),
                      const Spacer(),
                      const NwWordmark(size: 15),
                      const Spacer(),
                      NwIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh nearby services',
                        size: 44,
                        onPressed: () => ref.invalidate(emergencyProvider(anchor)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(emergencyProvider(anchor)),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 18, wide ? 0 : 16, 32),
                      children: [
                        Text('EMERGENCY', style: NwText.eyebrow),
                        const SizedBox(height: 6),
                        Text('Get help, right now', style: NwText.h1),
                        const SizedBox(height: 16),
                        _HeroCard(onCall: (number) => _call(context, number)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text('Nearby services', style: NwText.h2),
                            const SizedBox(width: 8),
                            NwPill(
                              label: '1.5 KM',
                              icon: Icons.radar_rounded,
                              color: NwColors.textMuted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From ${anchor.lat.toStringAsFixed(4)}, '
                          '${anchor.lng.toStringAsFixed(4)} · OpenStreetMap',
                          style: NwText.small,
                        ),
                        const SizedBox(height: 12),
                        async.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                          ),
                          error: (error, _) => NwErrorState(
                            title: 'Could not load nearby services',
                            message: 'NightWise could not reach the emergency service '
                                'database. If you need help now, call 112.',
                            onRetry: () => ref.invalidate(emergencyProvider(anchor)),
                          ),
                          data: (places) {
                            final police = places.where((p) => p.type == 'police').toList();
                            final hospitals = places.where((p) => p.type != 'police').toList();
                            if (places.isEmpty) {
                              return const NwDataNote(
                                text: 'No verified police stations or hospitals were found '
                                    'within 1.5 km in our OpenStreetMap dataset. This does not '
                                    'mean none exist — call 112 if you need help.',
                                icon: Icons.info_outline_rounded,
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (police.isNotEmpty) ...[
                                  _GroupTitle('Police stations', count: police.length),
                                  for (final place in police)
                                    _PlaceTile(
                                      place: place,
                                      onDirections: () => _goTo(context, ref, place),
                                      onCall: place.contact == null
                                          ? null
                                          : () => _call(context, place.contact!),
                                    ),
                                ],
                                if (hospitals.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _GroupTitle('Hospitals & clinics', count: hospitals.length),
                                  for (final place in hospitals)
                                    _PlaceTile(
                                      place: place,
                                      onDirections: () => _goTo(context, ref, place),
                                      onCall: place.contact == null
                                          ? null
                                          : () => _call(context, place.contact!),
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        const NwDataNote(
                          text: 'Emergency locations come from OpenStreetMap and may be '
                              'incomplete or out of date. If a listed service is closed or '
                              'unreachable, call 112.',
                          icon: Icons.info_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        _snack(context, 'Could not open the dialler. Dial $number manually.');
      }
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Could not open the dialler. Dial $number manually.');
      }
    }
  }

  void _goTo(BuildContext context, WidgetRef ref, EmergencyPlace place) {
    ref.read(destinationProvider.notifier).state = PlaceResult(
      id: 'emergency_${place.id}',
      name: place.displayName,
      lat: place.lat,
      lng: place.lng,
    );
    context.go('/home');
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onCall});
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NwColors.ink,
        borderRadius: BorderRadius.circular(NwRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NwColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sos_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In immediate danger?',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: NwColors.onDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Call emergency services first.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: NwColors.onDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'NightWise cannot contact anyone on your behalf. Your location is not '
            'shared automatically.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.5,
              color: NwColors.onDarkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NwActionButton(
                  label: 'Call 112',
                  icon: Icons.call_rounded,
                  onPressed: () => onCall('112'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NwColors.onDark,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => onCall('100'),
                  icon: const Icon(Icons.local_police_outlined, size: 17),
                  label: const Text('Police 100'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text, {required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text(text, style: NwText.label.copyWith(fontSize: 13)),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: NwColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: NwText.small.copyWith(fontSize: 10, color: NwColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.onDirections,
    this.onCall,
  });

  final EmergencyPlace place;
  final VoidCallback onDirections;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final isPolice = place.type == 'police';
    return NwCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPolice ? NwColors.infoSoft : NwColors.dangerSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isPolice ? Icons.local_police_outlined : Icons.local_hospital_outlined,
              color: isPolice ? NwColors.info : NwColors.danger,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NwText.label.copyWith(fontSize: 12.5, height: 1.3),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(_distance(place.distanceM), style: NwText.small.copyWith(fontSize: 10.5)),
                    if (!place.verified) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· unverified',
                        style: NwText.small.copyWith(fontSize: 10.5, color: NwColors.warning),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Directions',
            visualDensity: VisualDensity.compact,
            onPressed: onDirections,
            icon: const Icon(Icons.directions_outlined, size: 19),
          ),
          if (onCall != null)
            IconButton(
              tooltip: 'Call',
              visualDensity: VisualDensity.compact,
              onPressed: onCall,
              icon: const Icon(Icons.call_outlined, size: 19),
            ),
        ],
      ),
    );
  }

  String _distance(int metres) {
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km away';
    return '$metres m away';
  }
}