import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../core/models/models.dart';
import '../data/auth/auth_repository.dart';
import '../data/emergency/emergency_repository.dart';
import '../data/location/location_service.dart';
import '../data/profile/profile_repository.dart';
import '../data/reports/reports_repository.dart';
import '../data/routes/route_repository.dart';

// ---------------------------------------------------------------- infra

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
);

// ---------------------------------------------------------------- data

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(apiClientProvider),
    store: ref.watch(tokenStoreProvider),
  ),
);

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RouteRepository(ref.watch(apiClientProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

final emergencyRepositoryProvider = Provider<EmergencyRepository>(
  (ref) => EmergencyRepository(ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

// ---------------------------------------------------------------- auth

class AuthController extends StateNotifier<AsyncValue<Session?>> {
  AuthController(this._repository) : super(const AsyncValue.loading());

  final AuthRepository _repository;

  Future<void> restore() async {
    final session = await _repository.restore();
    state = AsyncData(session);
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final session = await _repository.login(email: email, password: password);
      state = AsyncData(session);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    try {
      final session = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AsyncData(session);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    state = const AsyncData(null);
  }

  void clearError() {
    final current = state.valueOrNull;
    state = AsyncData(current);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Session?>>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

// ---------------------------------------------------------------- trip state

/// Bengaluru map centre used before the user picks a start. It is a real,
/// labelled place and is never treated as a measured location.
const kDefaultCenter = LatLngPoint(12.9756, 77.6040);

final originProvider = StateProvider<LatLngPoint?>((ref) => null);

final destinationProvider = StateProvider<PlaceResult?>((ref) => null);

/// 'walk' | 'vehicle'
final modeProvider = StateProvider<String>((ref) => 'walk');

/// 'car' | 'two_wheeler'
final vehicleTypeProvider = StateProvider<String>((ref) => 'car');

final safetySliderProvider = StateProvider<double>((ref) => 0.8);

final departureTimeProvider =
    StateProvider<DateTime>((ref) => DateTime.now().add(const Duration(minutes: 5)));

final recommendationRequestProvider =
    StateProvider<RecommendationRequest?>((ref) => null);

final recommendationProvider =
    FutureProvider.autoDispose<Recommendation?>((ref) async {
  final request = ref.watch(recommendationRequestProvider);
  if (request == null) return null;
  return ref.watch(routeRepositoryProvider).recommend(request);
});

final emergencyProvider = FutureProvider.autoDispose
    .family<List<EmergencyPlace>, LatLngPoint>((ref, at) async {
  return ref
      .watch(emergencyRepositoryProvider)
      .nearby(at: at, radiusM: 1500);
});

final reportPointProvider = StateProvider<LatLngPoint?>((ref) => null);

final reportRadiusProvider = StateProvider<double>((ref) => 1200);

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).profile();
});

final nearbyReportsProvider = FutureProvider.autoDispose
    .family<List<CommunityReport>, LatLngPoint>((ref, at) async {
  return ref
      .watch(reportsRepositoryProvider)
      .nearby(at: at, radiusM: ref.watch(reportRadiusProvider).round());
});
