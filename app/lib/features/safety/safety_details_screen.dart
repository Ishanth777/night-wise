import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/warnings.dart';
import '../../widgets/indicator_bar.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Why this score?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NwColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NwColors.surfaceHigh),
            ),
            child: Row(
              children: [
                ScoreBadge(score: summary.safetyScore, size: 76, grade: summary.safetyGrade),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${route.labelTitle} route',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.durationText} · ${summary.distanceText}',
                        style: const TextStyle(color: NwColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ConfidencePill(confidence: summary.confidence),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Indicator breakdown'),
          const SizedBox(height: 4),
          const Text(
            'Each indicator is scored per road segment, then weighted and length-adjusted. '
            'Weights lean toward lighting and street activity at night.',
            style: TextStyle(color: NwColors.textMuted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: NwColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final indicator in indicators)
                  IndicatorBar(indicator: indicator),
              ],
            ),
          ),
          if (route.warnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Warnings'),
            const SizedBox(height: 8),
            for (final warning in _humanWarnings(route.warnings))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 17, color: NwColors.moderate),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (route.segments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Safety along the route'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  for (final segment in route.segments)
                    Expanded(
                      flex: segment.lengthM.round().clamp(1, 250),
                      child: Container(
                        height: 10,
                        color: NwTheme.scoreColor(segment.score),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('start', style: TextStyle(color: NwColors.textMuted, fontSize: 11)),
                Text('destination', style: TextStyle(color: NwColors.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 14),
            if (weakest.isNotEmpty) ...[
              const Text(
                'Weakest stretches',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final segment in weakest)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NwColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScoreBadge(score: segment.score, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_metres(segment.startM)} – ${_metres(segment.endM)} along route',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              segment.warnings.isNotEmpty
                                  ? humanizeWarning(segment.warnings.first)
                                  : _reason(segment),
                              style: const TextStyle(
                                color: NwColors.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          const SizedBox(height: 20),
          const _SectionTitle('Data provenance'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: 'lighting: ${route.streetlightProvenance.replaceAll('_', ' ')}',
                icon: Icons.lightbulb_outline,
                color: route.hasLimitedLightingData ? NwColors.limited : NwColors.safe,
              ),
              const StatusChip(
                label: 'hours: OSM + known gaps',
                icon: Icons.schedule,
                color: NwColors.textMuted,
              ),
              const StatusChip(
                label: 'community: moderated',
                icon: Icons.people_outline,
                color: NwColors.textMuted,
              ),
            ],
          ),
          if (route.dataNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              route.dataNotes,
              style: const TextStyle(color: NwColors.textMuted, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NwColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 17, color: NwColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NightWise safety scores are environmental estimates, not guarantees of personal safety. '
                    'Trust your instincts — if a street feels wrong, leave it.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
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
        ],
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
    return 'Lowest signal: ${weak.first.value.label.toLowerCase()} (${weak.first.value.score}/100).';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}
