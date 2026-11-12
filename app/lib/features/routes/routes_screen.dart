import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/night_map.dart';
import '../../widgets/nw_kit.dart';
import '../../widgets/route_card.dart';
import '../navigation/navigation_screen.dart';

class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  String? _selectedId;
  bool _saving = false;

  RouteOption? _selected(List<RouteOption> routes) {
    if (routes.isEmpty) return null;
    for (final route in routes) {
      if (route.routeId == _selectedId) return route;
    }
    for (final route in routes) {
      if (route.label == 'safest') return route;
    }
    return routes.first;
  }

  Future<void> _saveTrip(Recommendation recommendation) async {
    final request = ref.read(recommendationRequestProvider);
    if (request == null || _saving) return;
    final controller = TextEditingController(
      text: recommendation.mode == 'walk' ? 'Night walk' : 'Night drive',
    );
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save this trip'),
        content: TextField(
          controller: controller,
          maxLength: 80,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).saveRoute(
            label: label.isEmpty ? 'Saved trip' : label,
            mode: recommendation.mode,
            origin: request.origin,
            destination: request.destination,
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Trip saved — open it from Profile.')),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is AppFailure
                  ? error.message
                  : 'Could not save this trip (the limit is 2).',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openSafety(RouteOption route) => context.push('/safety', extra: route);

  void _startNavigation(Recommendation recommendation, RouteOption route) {
    final request = ref.read(recommendationRequestProvider);
    if (request == null) return;
    context.push(
      '/navigation',
      extra: NavigationArgs(
        route: route,
        origin: request.origin,
        destination: request.destination,
        mode: recommendation.mode,
      ),
    );
  }

  void _showDataSheet(Recommendation recommendation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => NwSheet(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Data & limitations', style: NwText.h2)),
                NwIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  size: 38,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in recommendation.dataHealth.entries)
              if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DataLine(
                    label: _humanKey(entry.key),
                    value: '${entry.value}',
                  ),
                ),
            const NwDataNote(
              text: 'Scores are environmental estimates from available data, not '
                  'guarantees of personal safety. Confidence reflects how much of the '
                  'route had verified signals.',
              icon: Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  static String _humanKey(String key) {
    switch (key) {
      case 'streetlightCoverage':
        return 'Street lighting coverage';
      case 'poiHourCoverage':
        return 'Opening-hours coverage';
      case 'notes':
        return 'Scoring notes';
      default:
        return key.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m.group(0)!.toLowerCase()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recommendationProvider);
    final request = ref.watch(recommendationRequestProvider);
    final wide = NwBreakpoints.isWide(context);
    final compact = NwBreakpoints.isCompact(context);

    return Scaffold(
      backgroundColor: NwColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: NightMap(
              center: request?.origin ?? kDefaultCenter,
              zoom: 14.2,
              routes: async.valueOrNull?.routes ?? const [],
              highlightedRouteId:
                  _selected(async.valueOrNull?.routes ?? const [])?.routeId,
              origin: request?.origin,
              destination: request?.destination,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 14, wide ? 24 : 14, 0),
              child: Row(
                children: [
                  NwIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to map',
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const Spacer(),
                  NwPill(
                    label: async.valueOrNull == null ? 'Comparing routes' : 'Live route data',
                    icon: async.valueOrNull == null
                        ? Icons.hourglass_top_rounded
                        : Icons.check_circle_outline_rounded,
                    color: NwColors.ink,
                    background: NwColors.panel,
                  ),
                  const SizedBox(width: 8),
                  NwIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh routes',
                    onPressed: () => ref.invalidate(recommendationProvider),
                  ),
                ],
              ),
            ),
          ),
          if (wide)
            Positioned(
              top: 86,
              right: 24,
              bottom: 24,
              width: 430,
              child: _RoutesPanel(
                recommendation: async.valueOrNull,
                error: async.hasError ? async.error : null,
                loading: async.isLoading,
                selected: _selected(async.valueOrNull?.routes ?? const []),
                selectedId: _selectedId,
                saving: _saving,
                onSelect: (id) => setState(() => _selectedId = id),
                onRetry: () => ref.invalidate(recommendationProvider),
                onSave: async.valueOrNull == null
                    ? null
                    : () => _saveTrip(async.valueOrNull!),
                onSafety: _openSafety,
                onStart: async.valueOrNull == null
                    ? null
                    : (route) => _startNavigation(async.valueOrNull!, route),
                onData: async.valueOrNull == null
                    ? null
                    : () => _showDataSheet(async.valueOrNull!),
                onHome: () => context.go('/home'),
                compact: compact,
                floating: true,
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.68,
                child: _RoutesPanel(
                  recommendation: async.valueOrNull,
                  error: async.hasError ? async.error : null,
                  loading: async.isLoading,
                  selected: _selected(async.valueOrNull?.routes ?? const []),
                  selectedId: _selectedId,
                  saving: _saving,
                  onSelect: (id) => setState(() => _selectedId = id),
                  onRetry: () => ref.invalidate(recommendationProvider),
                  onSave: async.valueOrNull == null
                      ? null
                      : () => _saveTrip(async.valueOrNull!),
                  onSafety: _openSafety,
                  onStart: async.valueOrNull == null
                      ? null
                      : (route) => _startNavigation(async.valueOrNull!, route),
                  onData: async.valueOrNull == null
                      ? null
                      : () => _showDataSheet(async.valueOrNull!),
                  onHome: () => context.go('/home'),
                  compact: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutesPanel extends StatelessWidget {
  const _RoutesPanel({
    required this.recommendation,
    required this.error,
    required this.loading,
    required this.selected,
    required this.selectedId,
    required this.saving,
    required this.onSelect,
    required this.onRetry,
    required this.onSave,
    required this.onSafety,
    required this.onStart,
    required this.onData,
    required this.onHome,
    required this.compact,
    this.floating = false,
  });

  final Recommendation? recommendation;
  final Object? error;
  final bool loading;
  final RouteOption? selected;
  final String? selectedId;
  final bool saving;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;
  final VoidCallback? onSave;
  final ValueChanged<RouteOption> onSafety;
  final ValueChanged<RouteOption>? onStart;
  final VoidCallback? onData;
  final VoidCallback onHome;
  final bool compact;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: const Radius.circular(NwRadii.sheet),
      bottom: Radius.circular(floating ? NwRadii.sheet : 0),
    );
    return Container(
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: radius,
        border: floating
            ? Border.all(color: NwColors.line)
            : const Border(top: BorderSide(color: NwColors.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24111410),
            blurRadius: 40,
            offset: Offset(0, -12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            if (compact)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NwColors.lineStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            Expanded(child: _content(context)),
            if (recommendation != null && selected != null)
              _Footer(
                recommendation: recommendation!,
                route: selected!,
                saving: saving,
                onSave: onSave,
                onSafety: () => onSafety(selected!),
                onStart: onStart == null ? null : () => onStart!(selected!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (loading && recommendation == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: const [
          Text('Comparing options', style: NwText.h1),
          SizedBox(height: 8),
          Text(
            'Checking lighting, open businesses, activity and community reports '
            'along each candidate route.',
            style: NwText.bodyMuted,
          ),
          SizedBox(height: 42),
          Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(height: 24),
          _LoadingSkeleton(),
        ],
      );
    }
    if (error != null || recommendation == null) {
      final message = error is AppFailure
          ? (error! as AppFailure).message
          : recommendation == null
              ? 'No trip is selected. Pick a destination first.'
              : 'Could not build routes right now.';
      return NwErrorState(
        title: recommendation == null ? 'Nothing to compare yet' : 'Routes unavailable',
        message: message,
        retryLabel: recommendation == null ? 'Back to map' : 'Try again',
        onRetry: recommendation == null ? onHome : onRetry,
      );
    }
    final routes = recommendation!.routes;
    if (routes.isEmpty) {
      return NwErrorState(
        title: 'No candidate routes',
        message: 'Valhalla returned no routes for this pair of points. Try a '
            'different destination or mode.',
        onRetry: onRetry,
      );
    }

    RouteOption? pick(String label) {
      for (final route in routes) {
        if (route.label == label) return route;
      }
      return null;
    }

    final safest = pick('safest');
    final fastest = pick('fastest');
    final summary = selected ?? safest ?? routes.first;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, compact ? 12 : 20, 20, 18),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ROUTE OPTIONS', style: NwText.eyebrow),
                  const SizedBox(height: 6),
                  Text(
                    routes.length == 1 ? 'One route tonight' : '${routes.length} routes tonight',
                    style: NwText.h1,
                  ),
                ],
              ),
            ),
            NwPill(
              label: recommendation!.mode == 'walk' ? 'Walking' : 'Driving',
              icon: recommendation!.mode == 'walk'
                  ? Icons.directions_walk_rounded
                  : Icons.directions_car_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TripLine(recommendation: recommendation!, summary: summary),
        if (safest != null && fastest != null && safest.routeId != fastest.routeId) ...[
          const SizedBox(height: 12),
          _ComparisonBanner(safest: safest, fastest: fastest),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < routes.length; i++) ...[
          NwFadeIn(
            delay: i * 45,
            child: RouteCard(
              route: routes[i],
              rank: i + 1,
              selected: routes[i].routeId == summary.routeId,
              onTap: () => onSelect(routes[i].routeId),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 2),
        NwDataNote(
          text: '${recommendation!.disclaimer.isEmpty ? AppConfig.disclaimer : recommendation!.disclaimer}'
              '  Tap for data sources and limitations.',
          icon: Icons.dataset_outlined,
          onTap: onData,
        ),
      ],
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.recommendation, required this.summary});
  final Recommendation recommendation;
  final RouteOption summary;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE d MMM · HH:mm').format(recommendation.computedFor.toLocal());
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        NwPill(
          label: time,
          icon: Icons.schedule_rounded,
          color: NwColors.textMuted,
          background: NwColors.panel,
        ),
        NwPill(
          label: recommendation.cacheHit
              ? 'cached result'
              : 'computed in ${recommendation.tookMs} ms',
          icon: Icons.bolt_rounded,
          color: NwColors.textMuted,
          background: NwColors.panel,
        ),
        NwPill(
          label: '${summary.summary.distanceText} · ${summary.summary.durationText}',
          icon: Icons.straighten_rounded,
          color: NwColors.ink,
          background: NwColors.panel,
        ),
      ],
    );
  }
}

class _ComparisonBanner extends StatelessWidget {
  const _ComparisonBanner({required this.safest, required this.fastest});
  final RouteOption safest;
  final RouteOption fastest;

  @override
  Widget build(BuildContext context) {
    final extraMin = ((safest.summary.durationS - fastest.summary.durationS) / 60).round();
    final delta = safest.summary.safetyScore - fastest.summary.safetyScore;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: NwColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 17, color: NwColors.ink),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              extraMin > 0
                  ? 'Safest adds $extraMin min and ${delta >= 0 ? '+' : ''}$delta '
                      'safety points over the fastest option.'
                  : 'Safest matches the fastest time with ${delta >= 0 ? '+' : ''}$delta '
                      'safety points.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: NwColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.recommendation,
    required this.route,
    required this.saving,
    required this.onSave,
    required this.onSafety,
    required this.onStart,
  });

  final Recommendation recommendation;
  final RouteOption route;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback onSafety;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: NwColors.surface,
        border: Border(top: BorderSide(color: NwColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSafety,
                    icon: const Icon(Icons.analytics_outlined, size: 17),
                    label: const Text('Why this score?'),
                  ),
                ),
                const SizedBox(width: 8),
                NwIconButton(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: 'Save trip',
                  busy: saving,
                  onPressed: onSave,
                ),
              ],
            ),
            const SizedBox(height: 8),
            NwActionButton(
              label: 'Start navigation',
              icon: Icons.navigation_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Container(
            height: 118,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: NwColors.panel,
              borderRadius: BorderRadius.circular(NwRadii.card),
              border: Border.all(color: NwColors.line),
            ),
          ),
      ],
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NwText.eyebrow),
        const SizedBox(height: 3),
        Text(value, style: NwText.bodyMuted.copyWith(fontSize: 12.5)),
      ],
    );
  }
}