import 'package:flutter/material.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';
import '../core/utils/warnings.dart';
import 'score_badge.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final RouteOption route;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final summary = route.summary;
    final limitedLight = route.hasLimitedLightingData;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? NwColors.surfaceHigh : NwColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? NwColors.primary : Colors.white.withValues(alpha: 0.06),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreBadge(score: summary.safetyScore, size: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              route.labelTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConfidencePill(confidence: summary.confidence),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.durationText} · ${summary.distanceText}',
                          style: const TextStyle(
                            color: NwColors.text,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary.tradeOff,
                          style: const TextStyle(
                            color: NwColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                if (limitedLight)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: StatusChip(
                      label: 'lighting not field-verified',
                      icon: Icons.nightlight_round,
                      color: NwColors.limited,
                    ),
                  ),
                if (route.warnings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 15, color: NwColors.moderate),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            humanizeWarning(route.warnings.first),
                            style: const TextStyle(
                              color: NwColors.moderate,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
