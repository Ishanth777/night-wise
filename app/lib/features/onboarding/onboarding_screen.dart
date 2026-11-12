import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../widgets/nw_kit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      eyebrow: 'SAFETY-FIRST ROUTING',
      title: 'Routes ranked by\nsafety, not speed.',
      body:
          'NightWise compares walking and driving options using street lighting, open businesses, activity signals and community reports — then shows you the trade-offs.',
      footnote: 'Real route geometry from a self-hosted Valhalla engine.',
    ),
    _SlideData(
      eyebrow: 'HONEST BY DESIGN',
      title: 'We show missing\ndata as missing.',
      body:
          'No verified lamp-post dataset? The lighting signal is marked lower-confidence. Unknown shop hours are never treated as closed. Every score carries its provenance.',
      footnote: 'Confidence is displayed on every route.',
    ),
    _SlideData(
      eyebrow: 'PRIVATE BY DEFAULT',
      title: 'Your location\nstays yours.',
      body:
          'No location history is stored. Report submissions are pseudonymous. Access tokens are short-lived and refresh tokens rotate on every use.',
      footnote: 'Bengaluru-only while we verify the data.',
    ),
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('nightwise.onboarded', true);
    } catch (_) {
      // Non-fatal: onboarding simply shows again next launch.
    }
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final horizontal = wide ? (width - 760) / 2 : 20.0;

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
              child: Row(
                children: [
                  const NwLogo(size: 36),
                  const SizedBox(width: 9),
                  const NwWordmark(size: 17),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 8),
                  child: _SlideCard(
                    data: _slides[index],
                    index: index,
                    dark: index == 0,
                    wide: wide,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 6),
              child: Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 26 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? NwColors.ink : NwColors.lineStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${_page + 1} / ${_slides.length}',
                    style: NwText.small,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 8),
              child: NwActionButton(
                label: _page == _slides.length - 1 ? 'Get started' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 18),
              child: Text(
                'NightWise scores are environmental estimates, not guarantees of personal safety.',
                textAlign: TextAlign.center,
                style: NwText.small.copyWith(fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.footnote,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String footnote;
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.data,
    required this.index,
    required this.dark,
    required this.wide,
  });

  final _SlideData data;
  final int index;
  final bool dark;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? NwColors.onDark : NwColors.ink;
    final muted = dark ? NwColors.onDarkMuted : NwColors.textMuted;
    return Container(
      decoration: BoxDecoration(
        color: dark ? NwColors.ink : NwColors.surface,
        borderRadius: BorderRadius.circular(NwRadii.sheet),
        border: Border.all(color: dark ? NwColors.ink : NwColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: CustomPaint(
              painter: _IllustrationPainter(index: index, dark: dark),
              child: const SizedBox.expand(),
            ),
          ),
          Flexible(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.eyebrow,
                    style: NwText.eyebrow.copyWith(
                      color: dark ? NwColors.accent : NwColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.title,
                    style: NwText.display.copyWith(
                      fontSize: wide ? 38 : 29,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.body,
                    style: NwText.body.copyWith(
                      color: muted,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: dark ? NwColors.accent : NwColors.ink,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          data.footnote,
                          style: NwText.small.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({required this.index, required this.dark});
  final int index;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = dark ? const Color(0xFF1A1D16) : const Color(0xFFE4E5DC);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    switch (index) {
      case 0:
        _mapScene(canvas, size);
      case 1:
        _dataScene(canvas, size);
      default:
        _privacyScene(canvas, size);
    }
  }

  void _mapScene(Canvas canvas, Size size) {
    final block = Paint()..color = dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.55);
    final edge = Paint()
      ..color = dark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCFD1C5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rng = math.Random(8);
    for (var i = 0; i < 26; i++) {
      final w = size.width * (0.06 + rng.nextDouble() * 0.16);
      final h = size.height * (0.06 + rng.nextDouble() * 0.2);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * rng.nextDouble(),
          size.height * rng.nextDouble(),
          w,
          h,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, block);
      canvas.drawRRect(rect, edge);
    }

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.85)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.72,
        size.width * 0.2,
        size.height * 0.48,
        size.width * 0.5,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.37,
        size.width * 0.66,
        size.height * 0.18,
        size.width * 0.9,
        size.height * 0.12,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = (dark ? NwColors.ink : Colors.white),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = NwColors.accent,
    );

    void dot(Offset point, Color color, double r) {
      canvas.drawCircle(point, r + 5, Paint()..color = (dark ? const Color(0xFF1A1D16) : NwColors.surface));
      canvas.drawCircle(point, r, Paint()..color = color);
      canvas.drawCircle(
        point,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = NwColors.ink,
      );
    }

    dot(Offset(size.width * 0.08, size.height * 0.85), NwColors.accent, 7);
    dot(Offset(size.width * 0.9, size.height * 0.12), NwColors.ink, 6);
  }

  void _dataScene(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.66,
        height: size.height * 0.62,
      ),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      card,
      Paint()..color = dark ? const Color(0xFF23261D) : NwColors.surface,
    );
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dark ? Colors.white12 : NwColors.line,
    );

    final left = size.width * 0.22;
    final right = size.width * 0.76;
    final bars = [0.82, 0.6, 0.34, 0.46];
    for (var i = 0; i < bars.length; i++) {
      final y = size.height * 0.28 + i * size.height * 0.11;
      final track = RRect.fromLTRBR(
        left,
        y,
        right,
        y + 7,
        const Radius.circular(99),
      );
      canvas.drawRRect(
        track,
        Paint()..color = dark ? Colors.white12 : NwColors.line,
      );
      final value = bars[i];
      canvas.drawRRect(
        RRect.fromLTRBR(left, y, left + (right - left) * value, y + 7, const Radius.circular(99)),
        Paint()..color = i == 2 ? NwColors.textMuted : NwColors.accent,
      );
    }

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.83),
      3,
      Paint()..color = NwColors.textMuted,
    );
  }

  void _privacyScene(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        center,
        size.width * 0.09 * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (dark ? Colors.white24 : NwColors.lineStrong).withValues(alpha: 0.5),
      );
    }
    canvas.drawCircle(
      center,
      size.width * 0.11,
      Paint()..color = NwColors.accent,
    );
    final lock = Path()
      ..moveTo(center.dx - 10, center.dy - 1)
      ..lineTo(center.dx - 10, center.dy - 8)
      ..arcToPoint(
        Offset(center.dx + 10, center.dy - 8),
        radius: const Radius.circular(10),
        clockwise: true,
      )
      ..lineTo(center.dx + 10, center.dy - 1)
      ..close();
    canvas.drawPath(
      lock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = NwColors.ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 8), width: 30, height: 24),
        const Radius.circular(7),
      ),
      Paint()..color = NwColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.dark != dark;
}