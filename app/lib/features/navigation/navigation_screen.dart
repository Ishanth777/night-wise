import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/warnings.dart';
import '../../providers/app_providers.dart';
import '../../widgets/night_map.dart';
import '../../widgets/score_badge.dart';

class NavigationArgs {
  const NavigationArgs({
    required this.route,
    required this.origin,
    required this.destination,
    required this.mode,
  });

  final RouteOption route;
  final LatLngPoint origin;
  final LatLngPoint destination;
  final String mode;
}

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key, required this.args});

  final NavigationArgs args;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  StreamSubscription<LatLngPoint>? _subscription;
  LatLngPoint? _live;
  bool _gpsUnavailable = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(locationServiceProvider).stream().listen(
      (point) {
        if (!mounted) return;
        setState(() {
          _live = point;
          _gpsUnavailable = false;
        });
      },
      onError: (Object _) {
        if (!mounted) return;
        setState(() => _gpsUnavailable = true);
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _endTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End navigation?'),
        content: const Text('Your route stays available until you pick a new destination.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End trip'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final route = args.route;
    final current = _live ?? args.origin;
    final geometryTotal = Geo.polylineLengthM(route.coordinates);
    final total = geometryTotal > 0 ? geometryTotal : route.summary.distanceM.toDouble();
    final remainingRaw = Geo.remainingAlongM(route.coordinates, current.lat, current.lng);
    final remaining = remainingRaw < 0 ? total : remainingRaw.clamp(0.0, total);
    final progress = total <= 0 ? 0.0 : (1 - remaining / total).clamp(0.0, 1.0);
    final etaSeconds = (route.summary.durationS * (remaining / (total <= 0 ? 1 : total))).round();
    final bearing = Geo.bearingDeg(current.lat, current.lng, args.destination.lat, args.destination.lng);
    final arrived = remaining < 45;

    final travelled = total - remaining;
    SegmentScore? stretch;
    for (final segment in route.segments) {
      if (travelled >= segment.startM && travelled <= segment.endM) {
        stretch = segment;
        break;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NightMap(
              center: current,
              zoom: 16,
              routes: [route],
              highlightedRouteId: route.routeId,
              origin: args.origin,
              destination: args.destination,
              current: current,
              follow: _live != null,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _GlassButton(icon: Icons.close, onTap: _endTrip),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: NwColors.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                arrived ? Icons.flag_rounded : Icons.navigation_rounded,
                                color: arrived ? NwColors.safe : NwColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  arrived
                                      ? 'You are near your destination'
                                      : 'Head ${Geo.compass(bearing)} · ${_distance(remaining)} to go',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_gpsUnavailable || _live == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          label: _gpsUnavailable
                              ? 'GPS unavailable — preview from start'
                              : 'Waiting for GPS fix…',
                          icon: Icons.gps_off,
                          color: NwColors.moderate,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: NwColors.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 26, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _distance(remaining),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                arrived
                                    ? 'Arrived'
                                    : '${_duration(etaSeconds)} remaining · arrive ${_arrival(etaSeconds)}',
                                style: const TextStyle(color: NwColors.textMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        ScoreBadge(score: route.summary.safetyScore, size: 54),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: NwColors.surfaceHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(NwColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoPill(
                            icon: Icons.shield_outlined,
                            label: stretch == null
                                ? 'Route safety ${route.summary.safetyScore}/100'
                                : 'This stretch ${stretch.score}/100',
                            color: NwTheme.scoreColor(stretch?.score ?? route.summary.safetyScore),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoPill(
                            icon: Icons.straighten,
                            label: '${_distance(total)} route',
                            color: NwColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (stretch != null && stretch.warnings.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: NwColors.moderate, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              humanizeWarning(stretch.warnings.first),
                              style: const TextStyle(
                                color: NwColors.moderate,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/report', extra: current),
                            icon: const Icon(Icons.flag_outlined, size: 17),
                            label: const Text('Report'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/emergency', extra: current),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NwColors.risky,
                              side: const BorderSide(color: NwColors.risky),
                            ),
                            icon: const Icon(Icons.emergency_outlined, size: 17),
                            label: const Text('Emergency'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GlassButton(icon: Icons.stop_circle_outlined, onTap: _endTrip),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _distance(double metres) {
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${metres.round()} m';
  }

  String _duration(int seconds) {
    if (seconds < 60) return '<1 min';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  String _arrival(int seconds) {
    final time = DateTime.now().add(Duration(seconds: seconds));
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: NwColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NwColors.surface.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 21)),
      ),
    );
  }
}
