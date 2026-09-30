/// ============================================================
/// WEATHER CARD (COMPACT, REUSABLE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/presentation/widgets/ = weather presentation layer
///
/// ✅ Responsibilities:
///   - Compact current-conditions summary for Home and Farm dashboards
///   - Independent skeleton / cached / stale / error / unavailable states
///   - Loads on its own so a failing card never blocks a dashboard
///
/// ❌ Does NOT:
///   - Block its parent surface while loading
///   - Poll or refetch on rebuild
///   - Display fabricated values when the backend sends null
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/weather/application/providers/weather_providers.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_ui.dart';

class WeatherCard extends ConsumerWidget {
  /// Where to resolve weather from. `null` renders the unavailable state.
  final WeatherRequestTarget? target;

  /// Display name of the place being shown (farm name, county, …).
  final String? locationLabel;

  /// Optional small heading rendered above the readings.
  final String? title;

  /// Tap target — normally opens the dedicated Weather page.
  final VoidCallback? onTap;

  const WeatherCard({
    super.key,
    this.target,
    this.locationLabel,
    this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final effectiveTarget = target ?? noWeatherTarget;
    final weather = ref.watch(weatherCurrentProvider(effectiveTarget));

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: weather.when(
            loading: () => const WeatherSkeleton(),
            error: (error, _) => WeatherErrorState(
              onRetry: () => ref.invalidate(weatherCurrentProvider),
            ),
            data: (bundle) => _buildData(context, bundle),
          ),
        ),
      ),
    );
  }

  Widget _buildData(BuildContext context, WeatherBundle? bundle) {
    final theme = Theme.of(context);
    final current = bundle?.current;

    if (current == null) {
      return WeatherUnavailable(onOpenWeather: onTap);
    }

    final condition = current.condition;
    final icon = weatherConditionIcon(condition);
    final iconColor = weatherConditionColor(condition, theme);
    final label = _resolvedLabel(current);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Primary: icon, temperature, condition ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeatherIconTile(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatTemperature(current.temperatureC),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 32,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.displaySmall?.color ??
                                Colors.black87,
                          ),
                        ),
                        if (condition != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              condition,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Freshness (cached / stale) ──
          if ((bundle?.stale ?? false) || bundle?.fetchedAt != null) ...[
            const SizedBox(height: 8),
            WeatherFreshnessLabel(
              label: formatUpdatedLabel(
                fetchedAt: bundle?.fetchedAt,
                stale: bundle?.stale ?? false,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Secondary: feels like, rain, humidity, wind ──
          Row(
            children: [
              WeatherMetric(
                icon: Icons.thermostat,
                label: 'Feels like',
                value: formatTemperature(current.feelsLikeC),
              ),
              const SizedBox(width: 8),
              WeatherMetric(
                icon: Icons.water_drop_outlined,
                label: 'Rain',
                value: formatPercent(current.precipitationProbabilityPercent),
                highlight:
                    (current.precipitationProbabilityPercent ?? 0) >= 50,
              ),
              const SizedBox(width: 8),
              WeatherMetric(
                icon: Icons.opacity,
                label: 'Humidity',
                value: formatPercent(current.humidityPercent),
              ),
              const SizedBox(width: 8),
              WeatherMetric(
                icon: Icons.air,
                label: 'Wind',
                value: formatWindSpeed(current.windSpeedMps),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _resolvedLabel(CurrentWeather current) {
    if (locationLabel != null && locationLabel!.trim().isNotEmpty) {
      return locationLabel!.trim();
    }
    if (current.latitude != null && current.longitude != null) {
      return '${current.latitude!.toStringAsFixed(2)}, '
          '${current.longitude!.toStringAsFixed(2)}';
    }
    return null;
  }
}
