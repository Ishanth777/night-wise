import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'nw_kit.dart';

/// Safety score ring. The score is always presented as number + word, with the
/// arc as a secondary cue — never colour alone.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,
    this.size = 64,
    this.grade,
    this.onDark = false,
  });

  final int score;
  final double size;
  final String? grade;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final word = grade ?? NwTheme.scoreWord(score);
    final arc = NwTheme.scoreColor(score);
    return Semantics(
      label: 'Safety score $score out of 100, $word',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: (score / 100).clamp(0.02, 1.0),
              strokeWidth: size * 0.055,
              backgroundColor: onDark ? Colors.white12 : NwColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(arc),
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: size * 0.31,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -1,
                      color: onDark ? NwColors.onDark : NwColors.ink,
                    ),
                  ),
                  SizedBox(height: size * 0.03),
                  Text(
                    word,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: size * 0.115,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: onDark ? NwColors.onDarkMuted : NwColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfidencePill extends StatelessWidget {
  const ConfidencePill({super.key, required this.confidence, this.onDark = false});

  final double confidence;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final label = confidence >= 0.6
        ? 'high confidence'
        : confidence >= 0.35
            ? 'partial data'
            : 'limited data';
    return NwPill(
      label: '$label · $pct%',
      icon: confidence >= 0.6 ? Icons.verified_outlined : Icons.info_outline,
      color: onDark
          ? NwColors.onDarkMuted
          : (confidence >= 0.35 ? NwColors.textMuted : NwColors.warning),
      background: onDark ? Colors.transparent : NwColors.panel,
      border: !onDark,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color = NwColors.textMuted,
    this.icon,
    this.background,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return NwPill(
      label: label,
      icon: icon,
      color: color,
      background: background ?? NwColors.panel,
    );
  }
}