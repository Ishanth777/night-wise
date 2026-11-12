import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/nw_kit.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.point});

  final LatLngPoint? point;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _note = TextEditingController();
  ReportKind _kind = ReportKind.poorLighting;
  int _severity = 3;
  bool _busy = false;
  bool _locating = false;
  LatLngPoint? _point;

  @override
  void initState() {
    super.initState();
    _point = widget.point ?? ref.read(originProvider) ?? ref.read(destinationProvider)?.point;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final position = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (position != null) _point = position;
    });
    if (position == null) {
      _snack('Location unavailable. You can still report from the selected route point.');
    }
  }

  Future<void> _submit() async {
    final point = _point;
    if (point == null) {
      _snack('Choose a location for this report.');
      return;
    }
    setState(() => _busy = true);
    try {
      final receipt = await ref.read(reportsRepositoryProvider).create(
            kind: _kind,
            severity: _severity,
            at: point,
            note: _note.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Report submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receipt.duplicatesNearby > 0
                    ? '${receipt.duplicatesNearby} similar report(s) were filed nearby in the last 24 hours.'
                    : 'Thank you — your report helps other people choose safer streets.',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                receipt.moderationNotice,
                style: NwText.small.copyWith(height: 1.45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(error is AppFailure ? error.message : 'Could not submit the report.');
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final wide = NwBreakpoints.isWide(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 14, wide ? 0 : 16, 0),
                  child: Row(
                    children: [
                      NwIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
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
                    padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 22, wide ? 0 : 16, 32),
                    children: [
                      Text('COMMUNITY', style: NwText.eyebrow),
                      const SizedBox(height: 6),
                      Text('Report a safety issue', style: NwText.h1),
                      const SizedBox(height: 8),
                      Text(
                        'Reports are reviewed before they affect route scores. '
                        'Describe places, not people.',
                        style: NwText.bodyMuted,
                      ),
                      const SizedBox(height: 20),
                      NwCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: point == null ? NwColors.canvas : NwColors.accentSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                point == null
                                    ? Icons.location_off_outlined
                                    : Icons.place_outlined,
                                size: 18,
                                color: NwColors.ink,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point == null ? 'No location selected' : 'Report location',
                                    style: NwText.label.copyWith(fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    point == null
                                        ? 'Use GPS or open this from a route'
                                        : '${point.lat.toStringAsFixed(5)}, '
                                            '${point.lng.toStringAsFixed(5)}',
                                    style: NwText.small,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _locating ? null : _useCurrentLocation,
                              child: _locating
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Use GPS'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('What are you seeing?', style: NwText.h3),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth > 520 ? 3 : 2;
                          final spacing = 8.0;
                          final itemWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final kind in ReportKind.values)
                                SizedBox(
                                  width: itemWidth,
                                  child: _KindTile(
                                    kind: kind,
                                    selected: _kind == kind,
                                    onTap: () => setState(() => _kind = kind),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('How serious is it?', style: NwText.h3),
                          const Spacer(),
                          Text(_severityLabel(_severity), style: NwText.small),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _severity = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  height: 10,
                                  margin: EdgeInsets.only(right: i == 5 ? 0 : 5),
                                  decoration: BoxDecoration(
                                    color: i <= _severity
                                        ? (i >= 4 ? NwColors.danger : NwColors.ink)
                                        : NwColors.line,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('minor concern', style: NwText.small.copyWith(fontSize: 10.5)),
                          Text('immediate risk', style: NwText.small.copyWith(fontSize: 10.5)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _note,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Details (optional)',
                          hintText: 'e.g. “Streetlight out on the east side, very dark after 9pm”',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const NwDataNote(
                        text: 'Anonymous and moderated. Only a hashed device fingerprint is '
                            'stored. Do not include names or personal details.',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 20),
                      NwActionButton(
                        label: _busy ? 'Submitting…' : 'Submit report',
                        icon: Icons.send_rounded,
                        busy: _busy,
                        onPressed: _busy || point == null ? null : _submit,
                      ),
                      if (point == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'A location is required before submitting.',
                          textAlign: TextAlign.center,
                          style: NwText.small.copyWith(color: NwColors.danger),
                        ),
                      ],
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

  String _severityLabel(int value) {
    switch (value) {
      case 1:
        return 'Minor concern';
      case 2:
        return 'Noticeable';
      case 3:
        return 'Concerning';
      case 4:
        return 'Serious';
      default:
        return 'Immediate risk';
    }
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ReportKind kind;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (kind) {
      case ReportKind.harassment:
        return Icons.person_off_outlined;
      case ReportKind.poorLighting:
        return Icons.lightbulb_outline;
      case ReportKind.unsafeIsolated:
        return Icons.nights_stay_outlined;
      case ReportKind.noFootpath:
        return Icons.directions_walk_rounded;
      case ReportKind.construction:
        return Icons.construction_outlined;
      case ReportKind.crowdSafe:
        return Icons.groups_outlined;
      case ReportKind.other:
        return Icons.more_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NwColors.ink : NwColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? NwColors.ink : NwColors.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 16,
                color: selected ? NwColors.accent : NwColors.inkMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? NwColors.onDark : NwColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}