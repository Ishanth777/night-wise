import 'package:flutter/material.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';
import 'nw_kit.dart';

/// One indicator row: label, score bar, numeric score and provenance status.
/// Missing data renders as "insufficient data" rather than a zero score
/// (plan FR-202 / §9.4).
class IndicatorBar extends StatelessWidget {
  const IndicatorBar({super.key, required this.indicator});

  final IndicatorScore indicator;

  @override
  Widget build(BuildContext context) {
    final hasData = indicator.status == 'ok' || indicator.status == 'estimated';
    final color = hasData ? NwTheme.scoreColor(indicator.score) : NwColors.textFaint;
    final value = hasData ? indicator.score / 100.0 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: NwColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon, size: 14, color: NwColors.inkMuted),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  indicator.label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasData)
                Text(
                  '${indicator.score}',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NwColors.ink,
                  ),
                )
              else
                Text(
                  _statusLabel(indicator.status),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: NwColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          NwProgressBar(value: value, height: 5, color: color),
          if (hasData && indicator.basis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Text(
                indicator.basis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: NwColors.textMuted,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _icon {
    switch (indicator.key) {
      case 'lights':
        return Icons.lightbulb_outline;
      case 'shops':
        return Icons.storefront_outlined;
      case 'activity':
        return Icons.directions_walk;
      case 'community':
        return Icons.forum_outlined;
      case 'emergency':
        return Icons.local_police_outlined;
      case 'road_quality':
        return Icons.add_road;
      default:
        return Icons.tune;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'no_data':
        return 'insufficient data';
      case 'stale':
        return 'out of date';
      case 'unverified':
        return 'unverified';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}