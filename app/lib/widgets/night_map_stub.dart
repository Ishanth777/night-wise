import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';
import '../core/utils/geo.dart';
import 'score_badge.dart';

/// Web fallback map: draws the route geometry and endpoints on a dark canvas
/// and supports tap-to-drop. The native builds use MapLibre GL.
class NightMap extends StatelessWidget {
  const NightMap({
    super.key,
    required this.center,
    this.zoom = 14.5,
    this.routes = const [],
    this.highlightedRouteId,
    this.origin,
    this.destination,
    this.current,
    this.onTap,
    this.follow = false,
  });

  final LatLngPoint center;
  final double zoom;
  final List<RouteOption> routes;
  final String? highlightedRouteId;
  final LatLngPoint? origin;
  final LatLngPoint? destination;
  final LatLngPoint? current;
  final ValueChanged<LatLngPoint>? onTap;
  final bool follow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = _Frame(center: center, zoom: zoom, size: size);
        return GestureDetector(
          onTapDown: onTap == null
              ? null
              : (details) => onTap!(frame.unproject(details.localPosition)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _MapPainter(
                  frame: frame,
                  routes: routes,
                  highlightedRouteId: highlightedRouteId,
                  origin: origin,
                  destination: destination,
                  current: current,
                ),
              ),
              const Positioned(
                left: 12,
                bottom: 12,
                child: StatusChip(
                  label: 'Map preview (web)',
                  icon: Icons.public,
                  color: NwColors.limited,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Frame {
  _Frame({required this.center, required this.zoom, required this.size})
      : latSpan = 0.018 * math.pow(2, 14.5 - zoom).toDouble(),
        lngSpan = 0.018 *
            math.pow(2, 14.5 - zoom).toDouble() /
            math.cos(center.lat * math.pi / 180);

  final LatLngPoint center;
  final double zoom;
  final Size size;
  final double latSpan;
  final double lngSpan;

  Offset project(double lat, double lng) {
    final x = (lng - center.lng) / lngSpan * size.width / 2 + size.width / 2;
    final y = (center.lat - lat) / latSpan * size.height / 2 + size.height / 2;
    return Offset(x, y);
  }

  LatLngPoint unproject(Offset offset) {
    final lng = (offset.dx - size.width / 2) / size.width * lngSpan * 2 + center.lng;
    final lat = center.lat - (offset.dy - size.height / 2) / size.height * latSpan * 2;
    return LatLngPoint(lat, lng);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.frame,
    required this.routes,
    required this.highlightedRouteId,
    required this.origin,
    required this.destination,
    required this.current,
  });

  final _Frame frame;
  final List<RouteOption> routes;
  final String? highlightedRouteId;
  final LatLngPoint? origin;
  final LatLngPoint? destination;
  final LatLngPoint? current;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B1220), Color(0xFF10243A), Color(0xFF0B1220)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      final y = size.height * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final ordered = [...routes];
    if (highlightedRouteId != null) {
      ordered.sort((a, b) {
        if (a.routeId == highlightedRouteId) return 1;
        if (b.routeId == highlightedRouteId) return -1;
        return 0;
      });
    }
    for (final route in ordered) {
      if (route.coordinates.length < 2) continue;
      final highlighted =
          highlightedRouteId == null || route.routeId == highlightedRouteId;
      final path = Path();
      for (var i = 0; i < route.coordinates.length; i++) {
        final point = frame.project(route.coordinates[i][1], route.coordinates[i][0]);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = highlighted ? 5 : 3
          ..color = (highlighted
                  ? NwTheme.scoreColor(route.summary.safetyScore)
                  : NwColors.limited)
              .withValues(alpha: highlighted ? 0.95 : 0.5),
      );
    }

    void marker(LatLngPoint? point, Color color, double radius) {
      if (point == null) return;
      final offset = frame.project(point.lat, point.lng);
      canvas.drawCircle(offset, radius + 2, Paint()..color = NwColors.night);
      canvas.drawCircle(offset, radius, Paint()..color = color);
    }

    marker(origin, NwColors.primary, 6);
    marker(destination, NwColors.risky, 7);
    marker(current, const Color(0xFF60A5FA), 6);

    if (current != null && destination != null) {
      final metres = Geo.distanceM(
        current!.lat,
        current!.lng,
        destination!.lat,
        destination!.lng,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${(metres / 1000).toStringAsFixed(1)} km to destination',
          style: const TextStyle(color: NwColors.text, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(12, 12));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}
