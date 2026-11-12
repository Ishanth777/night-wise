/// Platform map implementation.
///
/// Native (Android/iOS) uses the MapLibre GL plugin. Flutter web uses MapLibre
/// GL JS through a small DOM bridge, so route geometry and real OSM tiles are
/// rendered by an actual map engine rather than a decorative placeholder.
library;

export 'night_map_stub.dart'
    if (dart.library.io) 'night_map_native.dart'
    if (dart.library.js_interop) 'night_map_web.dart';