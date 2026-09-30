/// ============================================================
/// WEATHER PAGE (DEDICATED DETAIL VIEW)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/presentation/pages/ = weather presentation layer
///
/// ✅ Responsibilities:
///   1. Location header + selector (canonical locations only)
///   2. Current conditions
///   3. Forecast overview + hourly + daily
///   4. Last updated / cache indication and manual refresh
///
/// ❌ Does NOT:
///   - Offer agricultural advice, irrigation/spraying guidance, AI
///     interpretation, historical charts, satellite imagery or stations
///   - Poll automatically (backend cache TTL owns refresh policy)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/weather/application/providers/weather_location_provider.dart';
import 'package:famhub_app/features/weather/application/providers/weather_providers.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_forecast_views.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_ui.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';

class WeatherPage extends ConsumerWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolving = ref.watch(weatherLocationResolvingProvider);
    final candidate = ref.watch(weatherLocationProvider);
    final label = ref.watch(weatherLocationLabelProvider);
    final target = candidate?.target ?? noWeatherTarget;

    final current = ref.watch(weatherCurrentProvider(target));
    final forecast = ref.watch(weatherForecastProvider(target));

    final subtitle = label ??
        (resolving
            ? 'Finding your location…'
            : 'No weather location selected');

    return ShellPageContent(
      title: 'Weather',
      subtitle: subtitle,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Change location',
          icon: const Icon(Icons.place_outlined),
          onPressed: resolving
              ? null
              : () => _showLocationSheet(context, ref),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => _refresh(ref, target),
        ),
      ],
      child: Expanded(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () => _refresh(ref, target),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildBody(
              context,
              ref,
              current: current,
              forecast: forecast,
              targetUsable: target.isUsable,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<WeatherBundle?> current,
    required AsyncValue<WeatherBundle?> forecast,
    required bool targetUsable,
  }) {
    final theme = Theme.of(context);

    if (!targetUsable) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: WeatherUnavailable(
          message:
              'Set your profile location or select a farm to see the weather.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ── 1 + 2: Current conditions ──
        current.when(
          loading: () => const WeatherSkeleton(),
          error: (error, _) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant
                    .withValues(alpha: 0.8),
              ),
            ),
            child: WeatherErrorState(
              onRetry: () => ref.invalidate(weatherCurrentProvider),
            ),
          ),
          data: (bundle) {
            if (bundle == null || bundle.current == null) {
              return const WeatherUnavailable();
            }
            return WeatherCurrentPanel(
              current: bundle.current!,
              meta: bundle.meta,
              locationLabel: ref.read(weatherLocationLabelProvider),
            );
          },
        ),

        const SizedBox(height: 20),

        // ── 3a: Hourly forecast ──
        _sectionTitle(context, 'Hourly forecast'),
        const SizedBox(height: 8),
        forecast.when(
          loading: () => const _ForecastSkeleton(),
          error: (error, _) => WeatherErrorState(
            onRetry: () => ref.invalidate(weatherForecastProvider),
          ),
          data: (bundle) =>
              WeatherHourlyStrip(hours: bundle?.hourly ?? const []),
        ),

        const SizedBox(height: 20),

        // ── 3b: Daily forecast ──
        _sectionTitle(context, 'Daily forecast'),
        const SizedBox(height: 8),
        forecast.when(
          loading: () => const _ForecastSkeleton(),
          error: (error, _) => WeatherErrorState(
            onRetry: () => ref.invalidate(weatherForecastProvider),
          ),
          data: (bundle) =>
              WeatherDailyList(days: bundle?.daily ?? const []),
        ),

        const SizedBox(height: 12),
        _freshnessFooter(forecast, current),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _freshnessFooter(
    AsyncValue<WeatherBundle?> forecast,
    AsyncValue<WeatherBundle?> current,
  ) {
    final bundle = forecast.value ?? current.value;
    if (bundle == null) return const SizedBox.shrink();
    final label = formatUpdatedLabel(
      fetchedAt: bundle.fetchedAt,
      stale: bundle.stale,
    );
    if (label.isEmpty) return const SizedBox.shrink();
    return Center(child: WeatherFreshnessLabel(label: label));
  }

  // ─────────────────────────────────────────────────────────
  // REFRESH (user-triggered only)
  // ─────────────────────────────────────────────────────────

  Future<void> _refresh(WidgetRef ref, WeatherRequestTarget target) async {
    ref.invalidate(weatherCurrentProvider);
    ref.invalidate(weatherForecastProvider);

    await Future.wait(<Future<WeatherBundle?>>[
      ref.read(weatherCurrentProvider(target).future).catchError((_) => null),
      ref.read(weatherForecastProvider(target).future).catchError((_) => null),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  // LOCATION SELECTOR
  // ─────────────────────────────────────────────────────────

  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    final candidates = ref.read(weatherLocationCandidatesProvider);
    final selected = ref.read(weatherLocationProvider);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 8, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      'Weather location',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: WeatherUnavailable(
                    message:
                        'No locations available yet. Complete your profile '
                        'or add a farm to pick a weather location.',
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final isSelected =
                          selected != null && selected.key == candidate.key;
                      return ListTile(
                        leading: Icon(
                          candidate.source == 'farm'
                              ? Icons.agriculture_outlined
                              : Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(candidate.label),
                        subtitle: candidate.source == 'farm'
                            ? const Text('Farm location')
                            : const Text('Your profile location'),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          ref
                              .read(weatherSelectedLocationProvider.notifier)
                              .select(candidate);
                          ref.invalidate(weatherCurrentProvider);
                          ref.invalidate(weatherForecastProvider);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// FORECAST SKELETON
// ════════════════════════════════════════════════════════════

class _ForecastSkeleton extends StatelessWidget {
  const _ForecastSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = BoxDecoration(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    );

    return Row(
      children: [
        for (var i = 0; i < 5; i++) ...[
          Container(width: 64, height: 96, decoration: block),
          if (i < 4) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
