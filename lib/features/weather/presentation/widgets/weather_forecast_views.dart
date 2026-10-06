/// ============================================================
/// WEATHER FORECAST VIEWS (PAGE SECTIONS)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/presentation/widgets/ = weather presentation layer
///
/// ✅ Responsibilities:
///   - Gradient hero (current conditions), hourly strip, daily list
///   - Compact, responsive, low-end friendly
///
/// ❌ Does NOT:
///   - Fetch data (callers pass already-loaded models)
///   - Add agricultural advice, charts, or extra metadata
///   - Introduce a weather color system (brand tokens only)
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/core/theme/shell_theme_provider.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/presentation/widgets/weather_ui.dart';

// ════════════════════════════════════════════════════════════
// CURRENT CONDITIONS — GRADIENT HERO
// ════════════════════════════════════════════════════════════

class WeatherCurrentPanel extends StatelessWidget {
  final CurrentWeather current;
  final WeatherMeta meta;
  final String? locationLabel;

  /// `true` while a user-triggered refresh is in flight.
  final bool refreshing;

  const WeatherCurrentPanel({
    super.key,
    required this.current,
    required this.meta,
    this.locationLabel,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final condition = current.condition;
    final icon = weatherConditionIcon(condition);
    final stale = meta.stale || current.stale;

    final glow = icon == Icons.wb_sunny
        ? FamhubBrandTokens.orange
        : (icon == Icons.water_drop || icon == Icons.thunderstorm)
            ? Colors.white
            : FamhubBrandTokens.freshGreen;

    final location = locationLabel?.trim();
    final freshness = formatUpdatedLabel(
      fetchedAt: meta.fetchedAt ?? current.fetchedAt,
      stale: stale,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(FamhubBrandTokens.green, Colors.white, 0.14)!,
              FamhubBrandTokens.green,
              Color.lerp(FamhubBrandTokens.green, Colors.black, 0.38)!,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -58,
              child: _HeroGlow(color: glow, size: 190, alpha: 0.34),
            ),
            const Positioned(
              left: -60,
              bottom: -74,
              child: _HeroGlow(
                color: FamhubBrandTokens.freshGreen,
                size: 210,
                alpha: 0.15,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: WeatherGlassChip(
                          icon: Icons.location_on_outlined,
                          label: (location == null || location.isEmpty)
                              ? 'Current conditions'
                              : location,
                        ),
                      ),
                      const Spacer(),
                      if (freshness.isNotEmpty)
                        Flexible(
                          child: WeatherGlassChip(
                            icon: Icons.history_rounded,
                            label: freshness,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatTemperature(current.temperatureC),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 64,
                                height: 0.95,
                                letterSpacing: -2.5,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                              ),
                            ),
                            if (condition != null &&
                                condition.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                condition.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glow.withValues(alpha: 0.45),
                              blurRadius: 34,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 46, color: Colors.white),
                      ),
                    ],
                  ),

                  if (refreshing) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      _Detail(
                        icon: Icons.thermostat_rounded,
                        label: 'Feels like',
                        value: formatTemperature(current.feelsLikeC),
                      ),
                      const SizedBox(width: 8),
                      _Detail(
                        icon: Icons.opacity_rounded,
                        label: 'Humidity',
                        value: formatPercent(current.humidityPercent),
                      ),
                      const SizedBox(width: 8),
                      _Detail(
                        icon: Icons.umbrella_outlined,
                        label: 'Rain chance',
                        value:
                            formatPercent(current.precipitationProbabilityPercent),
                        highlight:
                            (current.precipitationProbabilityPercent ?? 0) >= 50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Detail(
                        icon: Icons.water_outlined,
                        label: 'Rainfall',
                        value: formatMillimetres(current.rainfallMm),
                      ),
                      const SizedBox(width: 8),
                      _Detail(
                        icon: Icons.air_rounded,
                        label: 'Wind',
                        value: formatWindSpeed(current.windSpeedMps),
                      ),
                      const SizedBox(width: 8),
                      _Detail(
                        icon: Icons.explore_outlined,
                        label: 'Wind dir.',
                        value: formatWindDirection(current.windDirectionDegrees),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft radial-looking blob used to give the hero depth.
class _HeroGlow extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;

  const _HeroGlow({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: alpha * 0.9),
            blurRadius: size * 0.55,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}

/// Frosted metric tile inside the hero.
class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = highlight
        ? FamhubBrandTokens.orangeDark
        : Colors.white;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.72)),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
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
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _HourlyCell(
          hour: hours[index],
          isNow: index == 0 && _isNow(hours[index].time),
        ),
      ),
    );
  }

  bool _isNow(DateTime? time) {
    if (time == null) return false;
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day &&
        time.hour == now.hour;
  }
}

class _HourlyCell extends StatelessWidget {
  final HourlyForecast hour;
  final bool isNow;

  const _HourlyCell({required this.hour, required this.isNow});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final probability = hour.precipitationProbabilityPercent;
    final icon = weatherConditionIcon(hour.condition);
    final iconColor = weatherConditionColor(hour.condition, theme);

    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isNow
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNow
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isNow ? 0.05 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isNow ? 'Now' : (hour.time == null ? '—' : formatForecastHour(hour.time!)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isNow
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            formatTemperature(hour.temperatureC),
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop_rounded,
                size: 10,
                color: (probability ?? 0) > 0
                    ? FamhubBrandTokens.orange
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  probability == null ? '—' : '$probability%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: (probability ?? 0) > 0
                        ? FamhubBrandTokens.orange
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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

    final week = _weekRange(days);

    return WeatherCardFrame(
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, i == 0 ? 14 : 0, 16, 14),
              child: _DailyRow(
                day: days[i],
                isFirst: i == 0,
                weekMin: week.min,
                weekMax: week.max,
              ),
            ),
            if (i != days.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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

  ({double? min, double? max}) _weekRange(List<DailyForecast> days) {
    double? min;
    double? max;
    for (final day in days) {
      final lo = day.tempMinC;
      final hi = day.tempMaxC;
      if (lo != null && (min == null || lo < min)) min = lo;
      if (hi != null && (max == null || hi > max)) max = hi;
    }
    return (min: min, max: max);
  }
}

class _DailyRow extends StatelessWidget {
  final DailyForecast day;
  final bool isFirst;
  final double? weekMin;
  final double? weekMax;

  const _DailyRow({
    required this.day,
    required this.isFirst,
    required this.weekMin,
    required this.weekMax,
  });

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

    final icon = weatherConditionIcon(day.condition);
    final iconColor = weatherConditionColor(day.condition, theme);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 60,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (date != null)
                    Text(
                      formatDate(date),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const Spacer(),
            Text(
              formatTemperature(day.tempMaxC),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            _RangeBar(
              min: day.tempMinC,
              max: day.tempMaxC,
              weekMin: weekMin,
              weekMax: weekMax,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              child: Text(
                formatTemperature(day.tempMinC),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 68),
              Expanded(
                child: Text(
                  secondary.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
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

/// Weekday low→high temperature range, positioned inside the week's spread.
class _RangeBar extends StatelessWidget {
  final double? min;
  final double? max;
  final double? weekMin;
  final double? weekMax;

  static const double _width = 76;

  const _RangeBar({
    required this.min,
    required this.max,
    required this.weekMin,
    required this.weekMax,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final track = Container(
      width: _width,
      height: 6,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    if (min == null || max == null || weekMin == null || weekMax == null) {
      return track;
    }

    final span = (weekMax! - weekMin!);
    if (span <= 0) return track;

    final lo = ((min! - weekMin!) / span).clamp(0.0, 1.0);
    final hi = ((max! - weekMin!) / span).clamp(0.0, 1.0);
    final left = lo * _width;
    final fill = ((hi - lo) * _width).clamp(4.0, _width);

    return SizedBox(
      width: _width,
      height: 6,
      child: Stack(
        children: [
          Positioned.fill(child: track),
          Positioned(
            left: (left + fill > _width ? _width - fill : left),
            top: 0,
            width: fill,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    FamhubBrandTokens.green,
                    FamhubBrandTokens.orange,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    return WeatherCardFrame(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
