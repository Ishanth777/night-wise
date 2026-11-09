import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

/// A fully-specified recommendation query. Value equality lets Riverpod
/// deduplicate identical requests.
class RecommendationRequest {
  const RecommendationRequest({
    required this.origin,
    required this.destination,
    required this.mode,
    required this.departureTime,
    this.vehicleType,
    this.safetyVsTime = 0.8,
  });

  final LatLngPoint origin;
  final LatLngPoint destination;
  final String mode;
  final String? vehicleType;
  final DateTime departureTime;
  final double safetyVsTime;

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'mode': mode,
        if (mode == 'vehicle') 'vehicleType': vehicleType ?? 'car',
        'departureTime': isoWithOffset(departureTime),
        'userPrefs': {'safetyVsTime': safetyVsTime},
      };

  @override
  bool operator ==(Object other) =>
      other is RecommendationRequest &&
      other.origin.lat == origin.lat &&
      other.origin.lng == origin.lng &&
      other.destination.lat == destination.lat &&
      other.destination.lng == destination.lng &&
      other.mode == mode &&
      other.vehicleType == vehicleType &&
      other.departureTime == departureTime &&
      other.safetyVsTime == safetyVsTime;

  @override
  int get hashCode => Object.hash(
        origin.lat,
        origin.lng,
        destination.lat,
        destination.lng,
        mode,
        vehicleType,
        departureTime,
        safetyVsTime,
      );
}

/// ISO 8601 with an explicit numeric offset — the backend rejects naive
/// timestamps so that time-of-day scoring is unambiguous (plan FR-105).
String isoWithOffset(DateTime value) {
  final local = value.toLocal();
  final base = local.toIso8601String().split('.').first;
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '$base$sign$hours:$minutes';
}

class RouteRepository {
  RouteRepository(this._api);

  final ApiClient _api;

  Future<Recommendation> recommend(RecommendationRequest request) async {
    final data = await _api.post('/routes/recommend', data: request.toJson());
    return Recommendation.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<PlaceResult>> searchPlaces(
    String query, {
    LatLngPoint? near,
  }) async {
    final data = await _api.get('/places/search', query: {
      'q': query,
      if (near != null) 'lat': near.lat,
      if (near != null) 'lng': near.lng,
    });
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PlaceResult.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> upstreamHealth() async {
    final data = await _api.get('/routes/upstream-health');
    return (data as Map).cast<String, dynamic>();
  }
}
