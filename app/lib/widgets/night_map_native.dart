import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';

/// MapLibre wrapper. Uses the bundled night raster style (OSM tiles for the
/// MVP; self-hosted vector tiles are the production upgrade in plan §5.3).
/// Route lines and markers are drawn as runtime annotations so no style
/// surgery is needed when the style changes.
class NightMap extends StatefulWidget {
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

  /// Keeps the camera on [current] as it updates (navigation mode).
  final bool follow;

  @override
  State<NightMap> createState() => NightMapState();
}

class NightMapState extends State<NightMap> {
  MapLibreMapController? _controller;
  String? _style;
  bool _styleReady = false;

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/maplibre/night_style.json')
        .then((value) {
      if (mounted) setState(() => _style = value);
    }).catchError((Object _) {
      if (mounted) setState(() => _style = null);
    });
  }

  @override
  void didUpdateWidget(covariant NightMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleReady || _controller == null) return;
    _paint();
    if (widget.follow &&
        widget.current != null &&
        widget.current != oldWidget.current) {
      _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.current!.lat, widget.current!.lng),
          16,
        ),
      );
    } else if (!widget.follow && widget.center != oldWidget.center) {
      _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.center.lat, widget.center.lng),
          widget.zoom,
        ),
      );
    }
  }

  Future<void> _paint() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    await controller.clearLines();
    await controller.clearCircles();

    final ordered = [...widget.routes];
    if (widget.highlightedRouteId != null) {
      ordered.sort((a, b) {
        if (a.routeId == widget.highlightedRouteId) return 1;
        if (b.routeId == widget.highlightedRouteId) return -1;
        return 0;
      });
    }

    for (final route in ordered) {
      final geometry = route.coordinates
          .map((c) => LatLng(c[1], c[0]))
          .toList(growable: false);
      if (geometry.length < 2) continue;
      final highlighted =
          widget.highlightedRouteId == null || route.routeId == widget.highlightedRouteId;
      // White casing keeps the lime line legible on the grayscale map.
      await controller.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: '#F8F8F3',
          lineWidth: highlighted ? 11 : 7,
          lineOpacity: highlighted ? 0.95 : 0.7,
          lineJoin: 'round',
        ),
      );
      await controller.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: highlighted ? '#C8F25B' : '#8B8F83',
          lineWidth: highlighted ? 6.5 : 4,
          lineOpacity: highlighted ? 1 : 0.65,
          lineJoin: 'round',
        ),
      );
    }

    if (widget.origin != null) {
      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(widget.origin!.lat, widget.origin!.lng),
          circleRadius: 7,
          circleColor: '#C8F25B',
          circleStrokeWidth: 3,
          circleStrokeColor: '#121410',
        ),
      );
    }
    if (widget.destination != null) {
      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(widget.destination!.lat, widget.destination!.lng),
          circleRadius: 8,
          circleColor: '#121410',
          circleStrokeWidth: 3,
          circleStrokeColor: '#F8F8F3',
        ),
      );
    }
    if (widget.current != null) {
      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(widget.current!.lat, widget.current!.lng),
          circleRadius: 7,
          circleColor: '#C8F25B',
          circleStrokeWidth: 3,
          circleStrokeColor: '#121410',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return const ColoredBox(
        color: NwColors.canvas,
        child: Center(
          child: CircularProgressIndicator(color: NwColors.ink),
        ),
      );
    }
    return MapLibreMap(
      styleString: style,
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.center.lat, widget.center.lng),
        zoom: widget.zoom,
      ),
      onMapCreated: (controller) {
        _controller = controller;
      },
      onStyleLoadedCallback: () {
        _styleReady = true;
        _paint();
      },
      onMapClick: widget.onTap == null
          ? null
          : (point, latLng) =>
              widget.onTap!(LatLngPoint(latLng.latitude, latLng.longitude)),
      trackCameraPosition: true,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
    );
  }
}
