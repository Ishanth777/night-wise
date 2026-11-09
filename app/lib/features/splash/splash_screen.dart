import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    await ref.read(authControllerProvider.notifier).restore();
    bool onboarded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboarded = prefs.getBool('nightwise.onboarded') ?? false;
    } catch (_) {
      onboarded = false;
    }
    // Keep the splash visible long enough to avoid a jarring flash.
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed < 800) {
      await Future<void>.delayed(Duration(milliseconds: 800 - elapsed));
    }
    if (!mounted) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (!onboarded) {
      context.go('/onboarding');
    } else if (session == null) {
      context.go('/auth');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1220), Color(0xFF10243A), Color(0xFF0B1220)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Logo(size: 84),
              SizedBox(height: 20),
              Text(
                'NightWise',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Come home with more confidence.',
                style: TextStyle(color: NwColors.textMuted, fontSize: 14),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: NwColors.surfaceHigh,
                  color: NwColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [NwColors.primary, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: NwColors.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(Icons.nights_stay_rounded, size: size * 0.48, color: NwColors.night),
    );
  }
}
