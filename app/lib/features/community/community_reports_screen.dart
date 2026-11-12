import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';
import '../../widgets/nw_shell.dart';

/// Published community reports around the current start point. Signed-in
/// users can confirm or deny a report; votes are a moderation signal and
/// never publish a report on their own (plan §9.4).
class CommunityReportsScreen extends ConsumerStatefulWidget {
  const CommunityReportsScreen({super.key});

  @override
  ConsumerState<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends ConsumerState<CommunityReportsScreen> {
  final Map<int, CommunityReport> _overrides = {};
  int? _voting;
  bool _expanded = false;

  Future<void> _vote(CommunityReport report, String vote) async {
    if (_voting != null) return;
    setState(() => _voting = report.id);
    try {
      final result = await ref.read(reportsRepositoryProvider).vote(id: report.id, vote: vote);
      if (!mounted) return;
      setState(() {
        _overrides[report.id] = report.withVote(result);
        _voting = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              vote == 'confirm'
                  ? 'Confirmed — thanks for verifying this report.'
                  : 'Marked as not accurate — moderators will see this signal.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _voting = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is AppFailure ? error.message : 'Could not record your vote.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final at = ref.watch(originProvider) ?? kDefaultCenter;
    final reports = ref.watch(nearbyReportsProvider(at));
    final wide = NwBreakpoints.isWide(context);

    return NwAppShell(
      current: 'community',
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 36 : 16, wide ? 28 : 14, wide ? 36 : 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMMUNITY', style: NwText.eyebrow),
                      const SizedBox(height: 6),
                      Text('Reports near you', style: NwText.h1),
                      const SizedBox(height: 5),
                      Text(
                        'Around ${at.lat.toStringAsFixed(3)}, ${at.lng.toStringAsFixed(3)} · '
                        'published reports only',
                        style: NwText.small,
                      ),
                    ],
                  ),
                ),
                NwIconButton(
                  icon: Icons.add_location_alt_outlined,
                  tooltip: 'Report an issue',
                  onPressed: () => context.push('/report'),
                  size: 44,
                ),
                const SizedBox(width: 8),
                NwIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh reports',
                  onPressed: () => ref.invalidate(nearbyReportsProvider(at)),
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Explainer(),
            const SizedBox(height: 18),
            reports.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
              error: (error, _) => NwErrorState(
                title: 'Could not load reports',
                message: error is AppFailure
                    ? error.message
                    : 'NightWise could not reach the community report database.',
                onRetry: () => ref.invalidate(nearbyReportsProvider(at)),
              ),
              data: (items) {
                final list = items.map((r) => _overrides[r.id] ?? r).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (list.isEmpty) {
                  return NwEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No published reports nearby',
                    message: 'Reports appear here after a moderator publishes them. '
                        'Silence is not proof of safety — missing data never improves a score.',
                    action: () => context.push('/report'),
                    actionLabel: 'Add a report',
                  );
                }
                final visible = _expanded ? list : list.take(8).toList();
                return Column(
                  children: [
                    for (final report in visible) ...[
                      _ReportCard(
                        report: report,
                        voting: _voting == report.id,
                        onVote: (vote) => _vote(report, vote),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (list.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: TextButton.icon(
                          onPressed: () => setState(() => _expanded = !_expanded),
                          icon: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _expanded
                                ? 'Show fewer'
                                : 'Show all ${list.length} reports',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const NwDataNote(
                      text: 'Votes are a moderation signal. A report never changes a '
                          'route score until a moderator publishes it.',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NwColors.accent,
        borderRadius: BorderRadius.circular(NwRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NwColors.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups_outlined, size: 18, color: NwColors.accent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help verify what the map cannot see',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NwColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Confirm a report to add a trusted moderation signal, or mark it '
                  'inaccurate if it looks stale. Reports are pseudonymous.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    height: 1.45,
                    color: NwColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.voting,
    required this.onVote,
  });

  final CommunityReport report;
  final bool voting;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final confirmed = report.myVote == 'confirm';
    final denied = report.myVote == 'deny';
    final severityColor = report.severity >= 4
        ? NwColors.danger
        : report.severity >= 3
            ? NwColors.warning
            : NwColors.ink;

    return NwCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 10, color: severityColor),
                    const SizedBox(width: 4),
                    Text(
                      report.kind.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: severityColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM · HH:mm').format(report.createdAt.toLocal()),
                style: NwText.small.copyWith(fontSize: 10.5),
              ),
            ],
          ),
          if (report.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 9),
            Text(
              report.note!.trim(),
              style: NwText.body.copyWith(fontSize: 13, height: 1.45),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 12, color: NwColors.textMuted),
              const SizedBox(width: 4),
              Text(
                report.point.toString(),
                style: NwText.small.copyWith(fontSize: 10.5),
              ),
              const SizedBox(width: 10),
              ...List.generate(
                5,
                (i) => Container(
                  width: 10,
                  height: 3,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i < report.severity ? severityColor : NwColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Spacer(),
              if (voting)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                _VoteButton(
                  icon: confirmed ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: '${report.confirmations}',
                  selected: confirmed,
                  tooltip: 'Confirm this report',
                  onTap: () => onVote('confirm'),
                ),
                const SizedBox(width: 2),
                _VoteButton(
                  icon: denied ? Icons.thumb_down : Icons.thumb_down_outlined,
                  label: '${report.denials}',
                  selected: denied,
                  tooltip: 'This report is not accurate',
                  onTap: () => onVote('deny'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Material(
        color: selected ? NwColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: NwColors.ink),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: NwText.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NwColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}