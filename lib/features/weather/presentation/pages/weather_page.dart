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
    final theme = Theme.of(context);
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
          icon: const Icon(Icons.place_outlined, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
            foregroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: resolving
              ? null
              : () => _showLocationSheet(context, ref),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
    if (!targetUsable) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: WeatherCardFrame(
          child: WeatherUnavailable(
            message:
                'Set your profile location or select a farm to see the weather.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ── Current conditions (gradient hero) ──
        current.when(
          loading: () => const WeatherCardFrame(
            child: WeatherSkeleton(compact: false),
          ),
          error: (error, _) => WeatherCardFrame(
            child: WeatherErrorState(
              onRetry: () => ref.invalidate(weatherCurrentProvider),
            ),
          ),
          data: (bundle) {
            if (bundle == null || bundle.current == null) {
              return const WeatherCardFrame(child: WeatherUnavailable());
            }
            return WeatherCurrentPanel(
              current: bundle.current!,
              meta: bundle.meta,
              locationLabel: ref.read(weatherLocationLabelProvider),
              refreshing: current.isLoading,
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Hourly forecast ──
        const WeatherSectionHeader(title: 'Hourly forecast'),
        const SizedBox(height: 10),
        forecast.when(
          loading: () => const WeatherCardFrame(
            child: _ForecastSkeleton(daily: false),
          ),
          error: (error, _) => WeatherCardFrame(
            child: WeatherErrorState(
              onRetry: () => ref.invalidate(weatherForecastProvider),
            ),
          ),
          data: (bundle) =>
              WeatherHourlyStrip(hours: bundle?.hourly ?? const []),
        ),

        const SizedBox(height: 24),

        // ── Daily forecast ──
        const WeatherSectionHeader(title: 'Daily forecast'),
        const SizedBox(height: 10),
        forecast.when(
          loading: () => const WeatherCardFrame(
            child: _ForecastSkeleton(daily: true),
          ),
          error: (error, _) => WeatherCardFrame(
            child: WeatherErrorState(
              onRetry: () => ref.invalidate(weatherForecastProvider),
            ),
          ),
          data: (bundle) =>
              WeatherDailyList(days: bundle?.daily ?? const []),
        ),

        const SizedBox(height: 32),
      ],
    );
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
  /// `false` → horizontal hourly cells, `true` → daily rows.
  final bool daily;

  const _ForecastSkeleton({this.daily = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = BoxDecoration(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(daily ? 12 : 18),
    );

    if (daily) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 5; row++) ...[
              if (row > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              Row(
                children: [
                  Container(width: 56, height: 30, decoration: block),
                  const SizedBox(width: 10),
                  Container(width: 34, height: 34, decoration: block),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 12, decoration: block)),
                  const SizedBox(width: 12),
                  Container(width: 76, height: 6, decoration: block),
                  const SizedBox(width: 8),
                  Container(width: 28, height: 14, decoration: block),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            Container(width: 74, height: 108, decoration: block),
            if (i < 4) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
