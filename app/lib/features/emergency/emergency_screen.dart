import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/score_badge.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(emergencyProvider(anchor)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(emergencyProvider(anchor)),
        color: NwColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NwColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NwColors.danger.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sos, color: NwColors.danger, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'In immediate danger?',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Call emergency services first. NightWise cannot contact anyone on your behalf.',
                    style: TextStyle(color: NwColors.textMuted, fontSize: 12.5, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NwColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _call(context, '112'),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Call 112'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _call(context, '100'),
                          icon: const Icon(Icons.local_police_outlined, size: 18),
                          label: const Text('Police 100'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nearby services · within 1.5 km',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'From ${anchor.lat.toStringAsFixed(4)}, ${anchor.lng.toStringAsFixed(4)} · OpenStreetMap',
              style: const TextStyle(color: NwColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: NwColors.primary),
                ),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 40, color: NwColors.textMuted),
                    const SizedBox(height: 10),
                    const Text(
                      'Could not load nearby services.',
                      style: TextStyle(color: NwColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(emergencyProvider(anchor)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (places) {
                final police = places.where((p) => p.type == 'police').toList();
                final hospitals = places.where((p) => p.type != 'police').toList();
                if (places.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NwColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No verified police stations or hospitals were found within 1.5 km in our dataset. '
                      'This does not mean none exist — call 112 if you need help.',
                      style: TextStyle(color: NwColors.textMuted, fontSize: 12.5, height: 1.5),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (police.isNotEmpty) ...[
                      const _PlaceGroupTitle('Police stations'),
                      for (final place in police)
                        _PlaceTile(place: place, onDirections: () => _goTo(context, ref, place)),
                    ],
                    if (hospitals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const _PlaceGroupTitle('Hospitals & clinics'),
                      for (final place in hospitals)
                        _PlaceTile(place: place, onDirections: () => _goTo(context, ref, place)),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Emergency locations come from OpenStreetMap and may be incomplete or out of date. '
              'If a listed service is closed or unreachable, call 112.',
              style: TextStyle(color: NwColors.textMuted, fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) _snack(context, 'Could not open the dialler. Dial $number manually.');
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not open the dialler. Dial $number manually.');
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

class _PlaceGroupTitle extends StatelessWidget {
  const _PlaceGroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onDirections});

  final EmergencyPlace place;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            place.type == 'police' ? Icons.local_police_outlined : Icons.local_hospital_outlined,
            color: place.type == 'police' ? const Color(0xFF60A5FA) : NwColors.risky,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _distance(place.distanceM),
                      style: const TextStyle(color: NwColors.textMuted, fontSize: 12),
                    ),
                    if (!place.verified) ...[
                      const SizedBox(width: 8),
                      const StatusChip(label: 'unverified', color: NwColors.limited),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Directions',
            onPressed: onDirections,
            icon: const Icon(Icons.directions_outlined, size: 20),
          ),
          if (place.contact != null && place.contact!.trim().isNotEmpty)
            IconButton(
              tooltip: 'Call',
              onPressed: () async {
                final uri = Uri(scheme: 'tel', path: place.contact!.trim());
                try {
                  await launchUrl(uri);
                } catch (_) {}
              },
              icon: const Icon(Icons.call_outlined, size: 20, color: NwColors.primary),
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
