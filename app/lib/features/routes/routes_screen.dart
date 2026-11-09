import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/route_card.dart';
import '../navigation/navigation_screen.dart';

class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  String? _selectedId;

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recommendationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe routes'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(recommendationProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: error is AppFailure
              ? error.message
              : 'Could not build routes right now.',
          onRetry: () => ref.invalidate(recommendationProvider),
        ),
        data: (recommendation) {
          if (recommendation == null) {
            return _ErrorState(
              message: 'No trip is selected. Pick a destination first.',
              onRetry: () => context.go('/home'),
              retryLabel: 'Back to map',
            );
          }
          if (recommendation.routes.isEmpty) {
            return _ErrorState(
              message: 'No candidate routes were available for this trip.',
              onRetry: () => ref.invalidate(recommendationProvider),
            );
          }
          final routes = recommendation.routes;
          final selected = _selected(routes);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _TripHeader(recommendation: recommendation),
                    const SizedBox(height: 14),
                    for (final route in routes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RouteCard(
                          route: route,
                          selected: route.routeId == selected?.routeId,
                          onTap: () => setState(() => _selectedId = route.routeId),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _DataHealthPanel(recommendation: recommendation),
                    const SizedBox(height: 18),
                    Text(
                      recommendation.disclaimer.isNotEmpty
                          ? recommendation.disclaimer
                          : AppConfig.disclaimer,
                      style: const TextStyle(
                        color: NwColors.textMuted,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              if (selected != null)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: const BoxDecoration(
                      color: NwColors.surface,
                      border: Border(
                        top: BorderSide(color: NwColors.surfaceHigh, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/safety', extra: selected),
                            child: const Text('Why this score?'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final request = ref.read(recommendationRequestProvider);
                              if (request == null) return;
                              context.push(
                                '/navigation',
                                extra: NavigationArgs(
                                  route: selected,
                                  origin: request.origin,
                                  destination: request.destination,
                                  mode: recommendation.mode,
                                ),
                              );
                            },
                            icon: const Icon(Icons.navigation_outlined, size: 18),
                            label: const Text('Start navigation'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE d MMM · HH:mm').format(recommendation.computedFor.toLocal());
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: NwColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            recommendation.mode == 'walk' ? Icons.directions_walk : Icons.directions_car,
            color: NwColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.mode == 'walk' ? 'Walking trip' : 'Vehicle trip',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                '$time · ${recommendation.cacheHit ? 'cached' : 'computed in ${recommendation.tookMs} ms'}',
                style: const TextStyle(color: NwColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DataHealthPanel extends StatelessWidget {
  const _DataHealthPanel({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final health = recommendation.dataHealth;
    final coverage = health['streetlightCoverage']?.toString();
    final provenance = health['streetlightProvenance']?.toString();
    final notes = health['notes']?.toString();
    if (coverage == null && provenance == null && (notes == null || notes.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NwColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NwColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dataset_outlined, size: 16, color: NwColors.textMuted),
              SizedBox(width: 6),
              Text('Data health',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          if (coverage != null && coverage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(coverage,
                style: const TextStyle(color: NwColors.textMuted, fontSize: 12, height: 1.4)),
          ],
          if (provenance != null && provenance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Streetlight provenance: ${provenance.replaceAll('_', ' ')}',
                style: const TextStyle(color: NwColors.textMuted, fontSize: 12)),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(notes,
                style: const TextStyle(color: NwColors.textMuted, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 3, color: NwColors.primary),
            ),
            SizedBox(height: 20),
            Text(
              'Checking lighting, activity and community reports\nalong candidate routes…',
              textAlign: TextAlign.center,
              style: TextStyle(color: NwColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 48, color: NwColors.textMuted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NwColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
