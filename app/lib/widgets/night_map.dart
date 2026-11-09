/// Platform map implementation.
///
/// Native (Android/iOS) uses MapLibre GL. The web build uses a lightweight
/// canvas preview because maplibre_gl_web 0.21 has not been updated for the
/// current Flutter web engine; native remains the primary target (plan §5.1).
library;

export 'night_map_stub.dart' if (dart.library.io) 'night_map_native.dart';
