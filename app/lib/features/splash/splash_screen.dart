import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final started = DateTime.now();
    await ref.read(authControllerProvider.notifier).restore();
    bool onboarded;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboarded = prefs.getBool('nightwise.onboarded') ?? false;
    } catch (_) {
      onboarded = false;
    }
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed < 700) {
      await Future<void>.delayed(Duration(milliseconds: 700 - elapsed));
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
    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SplashArt())),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.86, end: 1.0).animate(
                      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                    ),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: NwColors.ink,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33111410),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.nightlight_round,
                        size: 38,
                        color: NwColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const NwWordmark(size: 27),
                  const SizedBox(height: 8),
                  Text(
                    'Safer routes after dark.',
                    style: NwText.bodyMuted.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 108,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: NwColors.line,
                        color: NwColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Text(
              'BENGALURU · NIGHTWISE 1.0',
              textAlign: TextAlign.center,
              style: NwText.eyebrow.copyWith(fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = NwColors.lineStrong.withValues(alpha: 0.55);
    final path = Path()
      ..moveTo(-20, size.height * 0.7)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.55,
        size.width * 0.2,
        size.height * 0.25,
        size.width * 0.55,
        size.height * 0.3,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.35,
        size.width * 0.7,
        size.height * 0.1,
        size.width + 20,
        size.height * 0.12,
      );
    canvas.drawPath(path, paint);
    paint.color = NwColors.accentDeep.withValues(alpha: 0.22);
    paint.strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}