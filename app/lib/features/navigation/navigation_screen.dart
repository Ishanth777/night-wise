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
import '../../widgets/nw_kit.dart';
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
        content: const Text(
          'Your route stays available until you pick a new destination.',
        ),
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
    final total =
        geometryTotal > 0 ? geometryTotal : route.summary.distanceM.toDouble();
    final remainingRaw =
        Geo.remainingAlongM(route.coordinates, current.lat, current.lng);
    final remaining =
        remainingRaw < 0 ? total : remainingRaw.clamp(0.0, total);
    final progress = total <= 0 ? 0.0 : (1 - remaining / total).clamp(0.0, 1.0);
    final etaSeconds =
        (route.summary.durationS * (remaining / (total <= 0 ? 1 : total)))
            .round();
    final bearing = Geo.bearingDeg(
      current.lat,
      current.lng,
      args.destination.lat,
      args.destination.lng,
    );
    final arrived = remaining < 45;

    final travelled = total - remaining;
    SegmentScore? stretch;
    for (final segment in route.segments) {
      if (travelled >= segment.startM && travelled <= segment.endM) {
        stretch = segment;
        break;
      }
    }

    final wide = NwBreakpoints.isWide(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: Stack(
        fit: StackFit.expand,
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
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 12,
                12,
                wide ? 24 : 12,
                wide ? 24 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NwIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'End navigation',
                        onPressed: _endTrip,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GuidanceCard(
                          arrived: arrived,
                          bearing: bearing,
                          remaining: _distance(remaining),
                          eta: _duration(etaSeconds),
                        ),
                      ),
                    ],
                  ),
                  if (_gpsUnavailable || _live == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 58),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          label: _gpsUnavailable
                              ? 'GPS unavailable — showing your route from the start'
                              : 'Waiting for a GPS fix…',
                          icon: Icons.gps_off_rounded,
                          color: NwColors.warning,
                          background: NwColors.warningSoft,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Align(
                    alignment:
                        wide ? Alignment.bottomLeft : Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _TripPanel(
                        arrived: arrived,
                        wide: wide,
                        distance: _distance(remaining),
                        total: _distance(total),
                        eta: _duration(etaSeconds),
                        arrival: _arrival(etaSeconds),
                        progress: progress,
                        score: route.summary.safetyScore,
                        stretchScore: stretch?.score,
                        warning: stretch != null && stretch.warnings.isNotEmpty
                            ? humanizeWarning(stretch.warnings.first)
                            : null,
                        mode: args.mode,
                        gpsLive: _live != null,
                        onReport: () => context.push('/report', extra: current),
                        onEmergency: () =>
                            context.push('/emergency', extra: current),
                        onEnd: _endTrip,
                      ),
                    ),
                  ),
                ],
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

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.arrived,
    required this.bearing,
    required this.remaining,
    required this.eta,
  });

  final bool arrived;
  final double bearing;
  final String remaining;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: NwColors.panel,
        borderRadius: BorderRadius.circular(NwRadii.control),
        border: Border.all(color: NwColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14111410),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: arrived ? NwColors.accent : NwColors.ink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              arrived ? Icons.flag_rounded : Icons.navigation_rounded,
              size: 20,
              color: arrived ? NwColors.ink : NwColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived ? 'DESTINATION REACHED' : 'HEADING',
                  style: NwText.eyebrow.copyWith(
                    color: arrived ? NwColors.accentDeep : NwColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  arrived
                      ? 'You are near your destination'
                      : '${Geo.compass(bearing)} · $remaining to go',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NwText.h3.copyWith(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 16,
                  ),
                ),
                if (!arrived) ...[
                  const SizedBox(height: 1),
                  Text('About $eta remaining', style: NwText.small),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripPanel extends StatelessWidget {
  const _TripPanel({
    required this.arrived,
    required this.wide,
    required this.distance,
    required this.total,
    required this.eta,
    required this.arrival,
    required this.progress,
    required this.score,
    required this.stretchScore,
    required this.warning,
    required this.mode,
    required this.gpsLive,
    required this.onReport,
    required this.onEmergency,
    required this.onEnd,
  });

  final bool arrived;
  final bool wide;
  final String distance;
  final String total;
  final String eta;
  final String arrival;
  final double progress;
  final int score;
  final int? stretchScore;
  final String? warning;
  final String mode;
  final bool gpsLive;
  final VoidCallback onReport;
  final VoidCallback onEmergency;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(wide ? NwRadii.card : NwRadii.sheet);
    return Container(
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: radius,
        border: Border.all(color: NwColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24111410),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          arrived ? 'TRIP COMPLETE' : 'DISTANCE LEFT',
                          style: NwText.eyebrow,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          arrived ? 'You have arrived' : distance,
                          style: NwText.display.copyWith(
                            fontSize: arrived ? 27 : 34,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          arrived
                              ? 'Finish the trip when you are ready.'
                              : '$eta remaining · arrive $arrival',
                          style: NwText.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ScoreBadge(score: score, size: 58),
                ],
              ),
              const SizedBox(height: 14),
              NwProgressBar(value: progress),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${(progress * 100).round()}% of the route',
                    style: NwText.small,
                  ),
                  const Spacer(),
                  Text(total, style: NwText.small),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  NwPill(
                    label: stretchScore == null
                        ? 'Route $score/100'
                        : 'This stretch $stretchScore/100',
                    icon: Icons.shield_outlined,
                    color: NwTheme.scoreColor(stretchScore ?? score),
                  ),
                  NwPill(
                    label: mode == 'walk' ? 'Walking' : 'Driving',
                    icon: mode == 'walk'
                        ? Icons.directions_walk_rounded
                        : Icons.directions_car_outlined,
                    color: NwColors.textMuted,
                  ),
                  NwPill(
                    label: gpsLive ? 'GPS live' : 'Start point',
                    icon: gpsLive
                        ? Icons.my_location_rounded
                        : Icons.location_on_outlined,
                    color: gpsLive ? NwColors.success : NwColors.textMuted,
                  ),
                ],
              ),
              if (warning != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: NwColors.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: NwColors.warning,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          warning!,
                          style: NwText.small.copyWith(
                            color: NwColors.inkSoft,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PanelAction(
                      icon: Icons.flag_outlined,
                      label: 'Report',
                      onTap: onReport,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PanelAction(
                      icon: Icons.emergency_outlined,
                      label: 'Emergency',
                      onTap: onEmergency,
                      danger: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  NwIconButton(
                    icon: Icons.stop_circle_outlined,
                    tooltip: 'End trip',
                    onPressed: onEnd,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? NwColors.danger : NwColors.ink;
    return Material(
      color: NwColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NwRadii.control),
        side: BorderSide(
          color: danger ? NwColors.danger.withValues(alpha: 0.45) : NwColors.lineStrong,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(NwRadii.control),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NwText.label.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}