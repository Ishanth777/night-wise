import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models/models.dart';
import 'core/theme/theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/emergency/emergency_screen.dart';
import 'features/home/home_screen.dart';
import 'features/navigation/navigation_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/report/report_screen.dart';
import 'features/routes/routes_screen.dart';
import 'features/safety/safety_details_screen.dart';
import 'features/search/search_screen.dart';
import 'features/splash/splash_screen.dart';
import 'providers/app_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final public = location == '/' || location == '/auth' || location == '/onboarding';
      if (auth.isLoading && !public) return '/';
      final signedIn = auth.valueOrNull != null;
      if (!signedIn && !public) return '/auth';
      if (signedIn && location == '/auth') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/routes',
        builder: (context, state) => const RoutesScreen(),
      ),
      GoRoute(
        path: '/navigation',
        builder: (context, state) {
          final args = state.extra;
          if (args is! NavigationArgs) return const _MissingArgumentScreen();
          return NavigationScreen(args: args);
        },
      ),
      GoRoute(
        path: '/safety',
        builder: (context, state) {
          final route = state.extra;
          if (route is! RouteOption) return const _MissingArgumentScreen();
          return SafetyDetailsScreen(route: route);
        },
      ),
      GoRoute(
        path: '/emergency',
        builder: (context, state) {
          final extra = state.extra;
          return EmergencyScreen(point: extra is LatLngPoint ? extra : null);
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final extra = state.extra;
          return ReportScreen(point: extra is LatLngPoint ? extra : null);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 48, color: NwColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'We could not open that screen (${state.uri}).',
              style: const TextStyle(color: NwColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to map'),
            ),
          ],
        ),
      ),
    ),
  );
});

class _MissingArgumentScreen extends StatelessWidget {
  const _MissingArgumentScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined, size: 48, color: NwColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'This screen needs a route selection. Start again from the map.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NwColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to map'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
