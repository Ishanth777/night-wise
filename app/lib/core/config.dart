import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Runtime configuration. Override at build time:
///   flutter run --dart-define=NIGHTWISE_API_URL=http://192.168.1.10:3000/api
class AppConfig {
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('NIGHTWISE_API_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return 'http://localhost:3000/api';
    // Android emulator reaches the host machine through 10.0.2.2.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  /// Bengaluru service area (plan §11.2) — client-side guard mirrors backend.
  static const serviceBbox = (
    west: 77.30,
    east: 77.90,
    south: 12.70,
    north: 13.25,
  );

  static bool inServiceArea(double lat, double lng) =>
      lat >= serviceBbox.south &&
      lat <= serviceBbox.north &&
      lng >= serviceBbox.west &&
      lng <= serviceBbox.east;

  static const disclaimer =
      'NightWise safety scores are environmental estimates, not guarantees of personal safety.';
}
