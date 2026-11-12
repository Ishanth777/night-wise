import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

/// Profile, preference defaults and saved routes (plan §11.1, FR-402).
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> profile() async {
    final data = await _api.get('/me/profile');
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<UserSettings> updateSettings(UserSettings settings) async {
    final data = await _api.patch('/me/settings', data: settings.toJson());
    final map = (data as Map).cast<String, dynamic>();
    return UserSettings.fromJson((map['settings'] as Map?)?.cast<String, dynamic>());
  }

  Future<List<SavedRoute>> savedRoutes() async {
    final data = await _api.get('/me/saved-routes');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => SavedRoute.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<SavedRoute> saveRoute({
    required String label,
    required String mode,
    required LatLngPoint origin,
    required LatLngPoint destination,
  }) async {
    final data = await _api.post('/me/saved-routes', data: {
      'label': label,
      'mode': mode,
      'origin': origin.toJson(),
      'destination': destination.toJson(),
    });
    return SavedRoute.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> deleteSavedRoute(int id) => _api.delete('/me/saved-routes/$id');
}
