/// ============================================================
/// WEATHER FORECAST VIEWS (PAGE SECTIONS)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/presentation/widgets/ = weather presentation layer
///
/// ✅ Responsibilities:
///   - Current-conditions panel, hourly strip, daily list
///   - Compact, responsive, low-end friendly
///
/// ❌ Does NOT:
///   - Fetch data (callers pass already-loaded models)
///   - Add agricultural advice, charts, or extra metadata
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_ui.dart';

// ════════════════════════════════════════════════════════════
// CURRENT CONDITIONS
// ════════════════════════════════════════════════════════════

class WeatherCurrentPanel extends StatelessWidget {
  final CurrentWeather current;
  final WeatherMeta meta;
  final String? locationLabel;

  const WeatherCurrentPanel({
    super.key,
    required this.current,
    required this.meta,
    this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final condition = current.condition;
    final icon = weatherConditionIcon(condition);
    final color = weatherConditionColor(condition, theme);
    final stale = meta.stale || current.stale;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeatherIconTile(icon: icon, color: color, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTemperature(current.temperatureC),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 44,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (condition != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        condition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (locationLabel != null &&
                        locationLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              locationLabel!.trim(),
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
          const SizedBox(height: 12),
          WeatherFreshnessLabel(
            label: formatUpdatedLabel(
              fetchedAt: meta.fetchedAt ?? current.fetchedAt,
              stale: stale,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _Detail(
                label: 'Feels like',
                value: formatTemperature(current.feelsLikeC),
              ),
              _Detail(
                label: 'Humidity',
                value: formatPercent(current.humidityPercent),
              ),
              _Detail(
                label: 'Rain chance',
                value: formatPercent(current.precipitationProbabilityPercent),
                highlight:
                    (current.precipitationProbabilityPercent ?? 0) >= 50,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Detail(
                label: 'Rainfall',
                value: formatMillimetres(current.rainfallMm),
              ),
              _Detail(
                label: 'Wind',
                value: formatWindSpeed(current.windSpeedMps),
              ),
              _Detail(
                label: 'Wind dir.',
                value: formatWindDirection(current.windDirectionDegrees),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Detail({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? FamhubBrandTokens.orange
                  : theme.textTheme.titleMedium?.color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HOURLY
// ════════════════════════════════════════════════════════════

class WeatherHourlyStrip extends StatelessWidget {
  final List<HourlyForecast> hours;

  const WeatherHourlyStrip({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return const _ForecastEmpty(message: 'No hourly forecast available.');
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) => _HourlyCell(hour: hours[index]),
      ),
    );
  }
}

class _HourlyCell extends StatelessWidget {
  final HourlyForecast hour;

  const _HourlyCell({required this.hour});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final probability = hour.precipitationProbabilityPercent;

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hour.time == null ? '—' : formatForecastHour(hour.time!),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Icon(
            weatherConditionIcon(hour.condition),
            size: 20,
            color: weatherConditionColor(hour.condition, theme),
          ),
          const SizedBox(height: 6),
          Text(
            formatTemperature(hour.temperatureC),
            maxLines: 1,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            probability == null ? '—' : '$probability%',
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: (probability ?? 0) > 0
                  ? FamhubBrandTokens.orange
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DAILY
// ════════════════════════════════════════════════════════════

class WeatherDailyList extends StatelessWidget {
  final List<DailyForecast> days;

  const WeatherDailyList({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const _ForecastEmpty(message: 'No daily forecast available.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(14, i == 0 ? 12 : 0, 14, 12),
              child: _DailyRow(day: days[i], isFirst: i == 0),
            ),
            if (i != days.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailyForecast day;
  final bool isFirst;

  const _DailyRow({required this.day, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = day.date;
    final probability = day.precipitationProbabilityPercent;

    final secondary = <String>[];
    if (day.condition != null && day.condition!.trim().isNotEmpty) {
      secondary.add(day.condition!.trim());
    }
    if (probability != null) secondary.add('$probability% rain');
    if (day.rainfallMm != null) {
      secondary.add(formatMillimetres(day.rainfallMm));
    }

    return Row(
      children: [
        SizedBox(
          width: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFirst && date != null && _isToday(date)
                    ? 'Today'
                    : date == null
                        ? '—'
                        : formatWeekday(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (date != null)
                Text(
                  formatDate(date),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          weatherConditionIcon(day.condition),
          size: 22,
          color: weatherConditionColor(day.condition, theme),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            secondary.isEmpty ? '—' : secondary.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatTemperature(day.tempMaxC),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Text(
          formatTemperature(day.tempMinC),
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// ════════════════════════════════════════════════════════════
// SHARED EMPTY
// ════════════════════════════════════════════════════════════

class _ForecastEmpty extends StatelessWidget {
  final String message;

  const _ForecastEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 22, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
