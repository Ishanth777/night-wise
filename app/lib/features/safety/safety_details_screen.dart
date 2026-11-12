import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/warnings.dart';
import '../../widgets/indicator_bar.dart';
import '../../widgets/nw_kit.dart';
import '../../widgets/score_badge.dart';

class SafetyDetailsScreen extends ConsumerWidget {
  const SafetyDetailsScreen({super.key, required this.route});

  final RouteOption route;

  static const _order = [
    'lights',
    'shops',
    'activity',
    'community',
    'emergency',
    'road_quality',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicators = [
      for (final key in _order)
        if (route.indicators[key] != null) route.indicators[key]!,
    ];
    final sortedSegments = [...route.segments]..sort((a, b) => a.score.compareTo(b.score));
    final weakest = sortedSegments.take(5).toList();
    final summary = route.summary;
    final wide = NwBreakpoints.isWide(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 14, wide ? 0 : 16, 0),
                  child: Row(
                    children: [
                      NwIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back to routes',
                        size: 44,
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      ),
                      const Spacer(),
                      const NwWordmark(size: 15),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 18, wide ? 0 : 16, 32),
                    children: [
                      Text('SCORE EXPLAINED', style: NwText.eyebrow),
                      const SizedBox(height: 6),
                      Text('Why this route scores ${summary.safetyScore}', style: NwText.h1),
                      const SizedBox(height: 8),
                      Text(
                        'Every indicator is scored per road segment, then weighted and '
                        'length-adjusted. Missing data lowers confidence — it is never '
                        'treated as zero.',
                        style: NwText.bodyMuted,
                      ),
                      const SizedBox(height: 18),
                      _ScoreHero(route: route),
                      const SizedBox(height: 18),
                      const NwSectionHeading(
                        eyebrow: 'INDICATORS',
                        title: 'What shaped this score',
                      ),
                      const SizedBox(height: 10),
                      NwCard(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          children: [
                            for (final indicator in indicators)
                              IndicatorBar(indicator: indicator),
                          ],
                        ),
                      ),
                      if (route.warnings.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const NwSectionHeading(
                          eyebrow: 'WARNINGS',
                          title: 'Things to know',
                        ),
                        const SizedBox(height: 10),
                        for (final warning in _humanWarnings(route.warnings))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: NwColors.warningSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: NwColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        height: 1.45,
                                        color: NwColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      if (route.segments.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const NwSectionHeading(
                          eyebrow: 'ALONG THE ROUTE',
                          title: 'Safety by stretch',
                        ),
                        const SizedBox(height: 12),
                        _RouteStrip(route: route),
                        const SizedBox(height: 20),
                        if (weakest.isNotEmpty) ...[
                          const Text('Weakest stretches', style: NwText.label),
                          const SizedBox(height: 8),
                          for (final segment in weakest)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: NwColors.panel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: NwColors.line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ScoreBadge(score: segment.score, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_metres(segment.startM)} – ${_metres(segment.endM)} '
                                          'along route',
                                          style: NwText.label.copyWith(fontSize: 12),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          segment.warnings.isNotEmpty
                                              ? humanizeWarning(segment.warnings.first)
                                              : _reason(segment),
                                          style: NwText.small.copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                      const SizedBox(height: 22),
                      const NwSectionHeading(
                        eyebrow: 'PROVENANCE',
                        title: 'Where the data comes from',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          NwPill(
                            label: 'lighting: ${route.streetlightProvenance.replaceAll('_', ' ')}',
                            icon: Icons.lightbulb_outline,
                            color: route.hasLimitedLightingData
                                ? NwColors.textMuted
                                : NwColors.ink,
                            background: route.hasLimitedLightingData
                                ? NwColors.panel
                                : NwColors.accentSoft,
                            border: route.hasLimitedLightingData,
                          ),
                          const NwPill(
                            label: 'hours: OSM + known gaps',
                            icon: Icons.schedule_rounded,
                          ),
                          const NwPill(
                            label: 'community: moderated',
                            icon: Icons.forum_outlined,
                          ),
                        ],
                      ),
                      if (route.dataNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(route.dataNotes, style: NwText.small),
                      ],
                      const SizedBox(height: 18),
                      const NwDataNote(
                        text: 'NightWise safety scores are environmental estimates, not '
                            'guarantees of personal safety. Trust your instincts — if a '
                            'street feels wrong, leave it.',
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          final midpoint = route.coordinates.isEmpty
                              ? null
                              : route.coordinates[route.coordinates.length ~/ 2];
                          context.push(
                            '/report',
                            extra: midpoint == null
                                ? null
                                : LatLngPoint(midpoint[1], midpoint[0]),
                          );
                        },
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Report an issue on this route'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<String> _humanWarnings(List<String> raw) {
    final seen = <String>{};
    for (final warning in raw) {
      seen.add(humanizeWarning(warning));
    }
    return seen.toList();
  }

  static String _metres(double value) =>
      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)} km' : '${value.round()} m';

  static String _reason(SegmentScore segment) {
    final weak = segment.indicators.entries
        .where((entry) => entry.value.status != 'no_data')
        .toList()
      ..sort((a, b) => a.value.score.compareTo(b.value.score));
    if (weak.isEmpty) return 'Limited verified data for this stretch.';
    return 'Lowest signal: ${weak.first.value.label.toLowerCase()} '
        '(${weak.first.value.score}/100).';
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.route});
  final RouteOption route;

  @override
  Widget build(BuildContext context) {
    final summary = route.summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NwColors.ink,
        borderRadius: BorderRadius.circular(NwRadii.card),
      ),
      child: Row(
        children: [
          ScoreBadge(score: summary.safetyScore, size: 84, onDark: true),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NwColors.accent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    route.labelTitle.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: NwColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${summary.durationText} · ${summary.distanceText}',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: NwColors.onDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${NwTheme.scoreLabel(summary.safetyScore)} · '
                  '${(summary.confidence * 100).round()}% data confidence',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: NwColors.onDarkMuted,
                  ),
                ),
                if (summary.tradeOff.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary.tradeOff,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.4,
                      color: NwColors.onDarkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.route});
  final RouteOption route;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              for (final segment in route.segments)
                Expanded(
                  flex: (segment.lengthM.round() ~/ 20).clamp(1, 40),
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.only(right: 1),
                    color: NwTheme.scoreColor(segment.score),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text('start', style: NwText.small.copyWith(fontSize: 10)),
            const Spacer(),
            for (final entry in const [
              ('Limited', NwColors.danger),
              ('Moderate', NwColors.warning),
              ('Good', NwColors.accentDeep),
            ])
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: entry.$2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.$1,
                      style: NwText.small.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text('destination', style: NwText.small.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}