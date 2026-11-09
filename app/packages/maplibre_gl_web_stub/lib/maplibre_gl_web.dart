import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Intentionally a no-op: NightWise's web build uses the canvas preview in
/// `lib/widgets/night_map_stub.dart` instead of MapLibre GL JS.
class MapLibreMapPlugin {
  static void registerWith(Registrar registrar) {
    // no-op
  }
}
