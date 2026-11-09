import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/models/models.dart';

/// Geolocator wrapper (plan §12.3). Permission is only requested when the
/// user explicitly asks for their location; a soft "last known" probe never
/// prompts.
class LocationService {
  Future<LatLngPoint?> lastKnown() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return LatLngPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<LatLngPoint?> current({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLngPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return lastKnown();
    }
  }

  Stream<LatLngPoint> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).map((pos) => LatLngPoint(pos.latitude, pos.longitude));
  }
}
