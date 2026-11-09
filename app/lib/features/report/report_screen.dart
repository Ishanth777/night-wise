import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';

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
    _point = widget.point ??
        ref.read(originProvider) ??
        ref.read(destinationProvider)?.point;
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
                style: const TextStyle(color: NwColors.textMuted, fontSize: 12, height: 1.45),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Report a safety issue')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NwColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: NwColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point == null
                        ? 'No location selected'
                        : '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _locating ? null : _useCurrentLocation,
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Use GPS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('What are you reporting?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ReportKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text('Severity',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                _severityLabel(_severity),
                style: const TextStyle(color: NwColors.primary, fontSize: 12.5),
              ),
            ],
          ),
          Slider(
            value: _severity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_severity',
            activeColor: NwColors.primary,
            inactiveColor: NwColors.surfaceHigh,
            onChanged: (value) => setState(() => _severity = value.round()),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('minor', style: TextStyle(color: NwColors.textMuted, fontSize: 11)),
              Text('serious', style: TextStyle(color: NwColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NwColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: NwColors.primary),
                    SizedBox(width: 6),
                    Text('Privacy & moderation',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Reports are anonymous and moderated before they affect route scores. '
                  'Only a hashed device fingerprint is stored. Do not include names or personal details — report places, not people.',
                  style: TextStyle(color: NwColors.textMuted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy || point == null ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_busy ? 'Submitting…' : 'Submit report'),
          ),
        ],
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
        return 'Severe / immediate risk';
    }
  }
}
