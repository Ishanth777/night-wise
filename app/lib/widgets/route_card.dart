import 'package:flutter/material.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';
import '../core/utils/warnings.dart';
import 'nw_kit.dart';
import 'score_badge.dart';

/// A route comparison card in the "quiet map" language: white cards for
/// alternatives, black for the selected route, lime for the selected safety
/// meter. All values come from the recommendation payload.
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.rank,
  });

  final RouteOption route;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final summary = route.summary;
    final limitedLight = route.hasLimitedLightingData;
    final foreground = selected ? NwColors.onDark : NwColors.ink;
    final muted = selected ? NwColors.onDarkMuted : NwColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: '${route.labelTitle} route, ${summary.durationText}, '
          '${summary.distanceText}, safety score ${summary.safetyScore}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NwRadii.card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(compact ? 14 : 17),
            decoration: BoxDecoration(
              color: selected ? NwColors.ink : NwColors.panel,
              borderRadius: BorderRadius.circular(NwRadii.card),
              border: Border.all(
                color: selected ? NwColors.ink : NwColors.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (rank != null) ...[
                                Text(
                                  rank!.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _LabelTag(
                                label: route.labelTitle.toUpperCase(),
                                selected: selected,
                                fastest: route.label == 'fastest',
                              ),
                              if (route.label == 'safest') ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: NwColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 9),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                summary.durationText,
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: compact ? 25 : 30,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: -1,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '· ${summary.distanceText}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ScoreBadge(
                      score: summary.safetyScore,
                      size: compact ? 52 : 60,
                      onDark: selected,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                NwProgressBar(
                  value: summary.safetyScore / 100,
                  height: 5,
                  color: selected ? NwColors.accent : NwTheme.scoreColor(summary.safetyScore),
                  track: selected ? Colors.white12 : NwColors.line,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Safety ${summary.safetyScore}/100 · ${NwTheme.scoreLabel(summary.safetyScore)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    const Spacer(),
                    if (!compact)
                      ConfidencePill(confidence: summary.confidence, onDark: selected),
                  ],
                ),
                if (!compact && summary.tradeOff.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    summary.tradeOff,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.35,
                      color: muted,
                    ),
                  ),
                ],
                if (!compact && (limitedLight || route.warnings.isNotEmpty)) ...[
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (limitedLight)
                        StatusChip(
                          label: 'lighting not field-verified',
                          icon: Icons.nightlight_round,
                          color: selected ? NwColors.onDarkMuted : NwColors.textMuted,
                          background: selected ? Colors.transparent : NwColors.canvas,
                        ),
                      if (route.warnings.isNotEmpty)
                        StatusChip(
                          label: humanizeWarning(route.warnings.first),
                          icon: Icons.warning_amber_rounded,
                          color: selected ? NwColors.accent : NwColors.warning,
                          background: selected ? Colors.transparent : NwColors.warningSoft,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelTag extends StatelessWidget {
  const _LabelTag({
    required this.label,
    required this.selected,
    required this.fastest,
  });

  final String label;
  final bool selected;
  final bool fastest;

  @override
  Widget build(BuildContext context) {
    final isSafest = label == 'SAFEST';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? (isSafest ? NwColors.accent : Colors.white12)
            : (isSafest ? NwColors.accentSoft : NwColors.canvas),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fastest
                ? Icons.bolt_rounded
                : isSafest
                    ? Icons.shield_outlined
                    : Icons.alt_route_rounded,
            size: 11,
            color: selected
                ? (isSafest ? NwColors.ink : NwColors.onDark)
                : NwColors.ink,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: selected
                  ? (isSafest ? NwColors.ink : NwColors.onDark)
                  : NwColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}