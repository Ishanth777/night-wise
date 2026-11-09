import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

class EmergencyRepository {
  EmergencyRepository(this._api);

  final ApiClient _api;

  Future<List<EmergencyPlace>> nearby({
    required LatLngPoint at,
    int radiusM = 1500,
  }) async {
    final data = await _api.get('/emergency/nearby', query: {
      'lat': at.lat,
      'lng': at.lng,
      'radiusM': radiusM,
    });
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => EmergencyPlace.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
