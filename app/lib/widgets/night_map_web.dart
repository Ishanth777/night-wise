import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/models/models.dart';
import '../core/theme/theme.dart';

@JS('NightWiseMap.init')
external void _mapInit(JSString id, JSString options);

@JS('NightWiseMap.update')
external void _mapUpdate(JSString id, JSString state);

@JS('NightWiseMap.destroy')
external void _mapDestroy(JSString id);

@JS('nightwiseOnMapTap')
external set _setMapTap(JSFunction? callback);

/// Real MapLibre GL map for Flutter web.
///
/// Route geometry, origin/destination and the live position all come from the
/// API response; the bridge only draws them. Markers are native DOM elements so
/// they stay sharp at every pixel ratio.
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
  final bool follow;

  @override
  State<NightMap> createState() => _WebNightMapState();
}

class _WebNightMapState extends State<NightMap> {
  static int _sequence = 0;
  static _WebNightMapState? _tapOwner;

  late final String _domId = 'nw-map-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  late final String _viewType = _domId;
  bool _initialised = false;
  String _lastRouteSignature = '';
  String? _lastCentre;

  JSFunction? _tapHandler;

  @override
  void initState() {
    super.initState();
    final div = web.HTMLDivElement()
      ..id = _domId
      ..className = 'nw-map-root';
    div.style
      ..width = '100%'
      ..height = '100%'
      ..position = 'relative'
      ..backgroundColor = '#ECECE6';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => div,
    );

    _registerTap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sendInit();
      _sendUpdate(forceFit: true);
    });
  }

  void _registerTap() {
    if (widget.onTap == null) return;
    _tapOwner = this;
    _tapHandler ??= ((JSNumber lng, JSNumber lat) {
      _tapOwner?._handleTap(lng.toDartDouble, lat.toDartDouble);
    }).toJS;
    _setMapTap = _tapHandler!;
  }

  void _handleTap(double lng, double lat) {
    widget.onTap?.call(LatLngPoint(lat, lng));
  }

  Map<String, int> _fitPadding() {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 900;
    if (width >= 960) {
      // The planner panel floats over the right edge on desktop.
      return {'top': 120, 'right': 500, 'bottom': 120, 'left': 90};
    }
    if (width >= 640) {
      return {'top': 110, 'right': 120, 'bottom': 320, 'left': 120};
    }
    return {'top': 100, 'right': 44, 'bottom': 340, 'left': 44};
  }

  void _sendInit() {
    final message = jsonEncode({
      'lat': widget.center.lat,
      'lng': widget.center.lng,
      'zoom': widget.zoom,
    });
    _mapInit(_domId.toJS, message.toJS);
    _initialised = true;
  }

  void _sendUpdate({bool forceFit = false}) {
    if (!_initialised) return;
    final signature = widget.routes
        .map((r) => '${r.routeId}:${r.coordinates.length}')
        .join('|');
    final centreKey = '${widget.center.lat.toStringAsFixed(5)},'
        '${widget.center.lng.toStringAsFixed(5)}';
    final fit = forceFit ||
        (widget.routes.isNotEmpty &&
            signature != _lastRouteSignature) ||
        (widget.routes.isEmpty && centreKey != _lastCentre);
    _lastRouteSignature = signature;
    _lastCentre = centreKey;

    final payload = <String, dynamic>{
      'center': widget.center.toJson(),
      'zoom': widget.zoom,
      'selectedRouteId': widget.highlightedRouteId,
      'origin': widget.origin?.toJson(),
      'destination': widget.destination?.toJson(),
      'current': widget.current?.toJson(),
      'follow': widget.follow,
      'fit': fit,
      'fitPadding': widget.routes.isNotEmpty ? _fitPadding() : null,
      'routes': [
        for (final route in widget.routes)
          {
            'id': route.routeId,
            'label': route.label,
            'coordinates': route.coordinates,
          },
      ],
    };
    _mapUpdate(_domId.toJS, jsonEncode(payload).toJS);
  }

  @override
  void didUpdateWidget(covariant NightMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTap == null && widget.onTap != null) {
      _registerTap();
    }
    if (oldWidget.onTap != null && widget.onTap == null && _tapOwner == this) {
      _tapOwner = null;
      _setMapTap = null;
    }
    _sendUpdate();
  }

  @override
  void dispose() {
    if (_tapOwner == this) {
      _tapOwner = null;
      _setMapTap = null;
    }
    _mapDestroy(_domId.toJS);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Map of Bengaluru with the selected night-time route',
      child: ClipRect(
        child: ColoredBox(
          color: NwColors.canvas,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}