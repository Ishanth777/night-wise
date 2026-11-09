import 'package:flutter/material.dart';

import '../core/models/models.dart';
import '../core/theme/theme.dart';

/// One indicator row: label, score bar, numeric score and provenance status.
/// Missing data renders as "insufficient data" rather than a zero score
/// (plan FR-202 / §9.4).
class IndicatorBar extends StatelessWidget {
  const IndicatorBar({super.key, required this.indicator});

  final IndicatorScore indicator;

  @override
  Widget build(BuildContext context) {
    final hasData = indicator.status == 'ok' || indicator.status == 'estimated';
    final color = hasData
        ? NwTheme.scoreColor(indicator.score)
        : NwColors.limited;
    final value = hasData ? indicator.score / 100.0 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  indicator.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (hasData)
                Text(
                  '${indicator.score}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                )
              else
                Text(
                  _statusLabel(indicator.status),
                  style: const TextStyle(
                    color: NwColors.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: NwColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (hasData && indicator.basis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              indicator.basis,
              style: const TextStyle(color: NwColors.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
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
