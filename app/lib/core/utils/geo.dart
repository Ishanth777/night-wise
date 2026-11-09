import 'dart:math' as math;

/// Small geodesy helpers used by the navigation preview. Distances are
/// great-circle metres; projections use an equirectangular approximation,
/// which is accurate enough at Bengaluru's latitude for UI guidance.
class Geo {
  static const double earthRadiusM = 6371000.0;

  static double distanceM(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Compass bearing in degrees (0 = north) from point A to point B.
  static double bearingDeg(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _rad(lng2 - lng1);
    final y = math.sin(dLng) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dLng);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  static String compass(double bearing) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = (((bearing % 360) / 45).round()) % 8;
    return names[idx];
  }

  static double polylineLengthM(List<List<double>> coordinates) {
    var total = 0.0;
    for (var i = 1; i < coordinates.length; i++) {
      total += distanceM(
        coordinates[i - 1][1],
        coordinates[i - 1][0],
        coordinates[i][1],
        coordinates[i][0],
      );
    }
    return total;
  }

  /// Distance still to travel along [coordinates] ([lng, lat] pairs) from the
  /// point closest to ([lat], [lng]). Returns -1 for an empty geometry.
  static double remainingAlongM(
    List<List<double>> coordinates,
    double lat,
    double lng,
  ) {
    if (coordinates.length < 2) return -1;
    var bestDist = double.infinity;
    var bestRemaining = 0.0;
    var cumulative = 0.0;
    for (var i = 1; i < coordinates.length; i++) {
      final a = coordinates[i - 1];
      final b = coordinates[i];
      final segLen = distanceM(a[1], a[0], b[1], b[0]);
      final projection = _project(a, b, lat, lng);
      if (projection.distance < bestDist) {
        bestDist = projection.distance;
        bestRemaining = cumulative + segLen * (1 - projection.fraction);
      }
      cumulative += segLen;
    }
    return bestRemaining;
  }

  static _Projection _project(
    List<double> a,
    List<double> b,
    double lat,
    double lng,
  ) {
    final scale = math.cos(_rad(lat));
    final ax = (a[0] - lng) * scale;
    final ay = a[1] - lat;
    final bx = (b[0] - lng) * scale;
    final by = b[1] - lat;
    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    var t = lenSq == 0 ? 0.0 : -(ax * dx + ay * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final px = ax + dx * t;
    final py = ay + dy * t;
    final dist =
        math.sqrt(px * px + py * py) * earthRadiusM * math.pi / 180.0;
    return _Projection(dist, t);
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;
}

class _Projection {
  const _Projection(this.distance, this.fraction);
  final double distance;
  final double fraction;
}
