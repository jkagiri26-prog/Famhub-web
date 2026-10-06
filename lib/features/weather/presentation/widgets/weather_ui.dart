/// ============================================================
/// WEATHER UI PRIMITIVES (SHARED, COMPACT, FAMHUB-NATIVE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/presentation/widgets/ = weather presentation layer
///
/// ✅ Responsibilities:
///   - Small building blocks shared by the Weather card and page
///   - Loading / error / unavailable states that never block a dashboard
///   - Formatting helpers that preserve nulls (never invent zeros)
///
/// ❌ Does NOT:
///   - Introduce a separate weather color system (brand tokens only)
///   - Contain fetching or state logic
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/core/theme/shell_theme_provider.dart';

// ════════════════════════════════════════════════════════════
// ICONS
// ════════════════════════════════════════════════════════════

/// Resolve a NORMALIZED condition label to a Material icon.
///
/// Only generic wording is matched — provider codes are never interpreted.
IconData weatherConditionIcon(String? condition) {
  final text = (condition ?? '').toLowerCase().trim();
  if (text.isEmpty) return Icons.wb_cloudy;

  if (text.contains('thunder') || text.contains('storm')) {
    return Icons.thunderstorm;
  }
  if (text.contains('snow') || text.contains('sleet') || text.contains('hail')) {
    return Icons.ac_unit;
  }
  if (text.contains('rain') || text.contains('drizzle') || text.contains('shower')) {
    return Icons.water_drop;
  }
  if (text.contains('fog') || text.contains('mist') || text.contains('haze')) {
    return Icons.blur_on;
  }
  if (text.contains('overcast')) return Icons.cloud;
  if (text.contains('cloud') || text.contains('partly')) return Icons.wb_cloudy;
  if (text.contains('clear') || text.contains('sun')) return Icons.wb_sunny;
  return Icons.wb_cloudy;
}

Color weatherConditionColor(String? condition, ThemeData theme) {
  final icon = weatherConditionIcon(condition);
  if (icon == Icons.wb_sunny) return FamhubBrandTokens.orange;
  if (icon == Icons.water_drop || icon == Icons.thunderstorm) {
    return theme.colorScheme.primary;
  }
  return theme.colorScheme.onSurfaceVariant;
}

// ════════════════════════════════════════════════════════════
// FORMATTING — nulls stay null, never rendered as 0
// ════════════════════════════════════════════════════════════

String _compact(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) return rounded.toInt().toString();
  return value.toStringAsFixed(1);
}

/// "24°" — or an em dash when the backend sent null.
String formatTemperature(double? celsius) =>
    celsius == null ? '—' : '${_compact(celsius)}°';

/// "70%" — or an em dash when the backend sent null.
String formatPercent(int? value) => value == null ? '—' : '$value%';

/// "3.4 mm" — or an em dash when the backend sent null.
String formatMillimetres(double? mm) =>
    mm == null ? '—' : '${_compact(mm)} mm';

/// "4.2 m/s" — or an em dash when the backend sent null.
String formatWindSpeed(double? metresPerSecond) =>
    metresPerSecond == null ? '—' : '${_compact(metresPerSecond)} m/s';

const List<String> _compassPoints = <String>[
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
];

/// Compass label for a wind direction in degrees — or an em dash.
String formatWindDirection(double? degrees) {
  if (degrees == null) return '—';
  final normalized = ((degrees % 360) + 360) % 360;
  final index = ((normalized / 22.5).round()) % _compassPoints.length;
  return _compassPoints[index];
}

const List<String> _monthNames = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdayNames = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// Short weekday label (Mon … Sun).
String formatWeekday(DateTime date) => _weekdayNames[date.weekday - 1];

/// "12 Oct"
String formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]}';

/// "09:00"
String formatHour(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:00';

/// Human "last updated" line. Stale responses read calmly, not as errors.
String formatUpdatedLabel({DateTime? fetchedAt, required bool stale}) {
  if (stale) return 'Updated earlier';
  if (fetchedAt == null) return '';

  final elapsed = DateTime.now().difference(fetchedAt);
  if (elapsed.isNegative || elapsed.inSeconds < 45) return 'Updated just now';
  if (elapsed.inMinutes < 60) return 'Updated ${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return 'Updated ${elapsed.inHours} hr ago';
  return 'Updated ${fetchedAt.day} ${_monthNames[fetchedAt.month - 1]}';
}

/// Hour label — "Now" for the current hour, otherwise "09:00".
String formatForecastHour(DateTime time) {
  final now = DateTime.now();
  if (time.year == now.year &&
      time.month == now.month &&
      time.day == now.day &&
      time.hour == now.hour) {
    return 'Now';
  }
  return formatHour(time);
}

// ════════════════════════════════════════════════════════════
// SHARED PIECES
// ════════════════════════════════════════════════════════════

/// Card chrome used by the Weather page so loading / error / unavailable
/// states keep the same footprint and elevation as the data panels.
class WeatherCardFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const WeatherCardFrame({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// Editorial section heading: gradient rule + tracked uppercase label.
class WeatherSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const WeatherSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [FamhubBrandTokens.orange, FamhubBrandTokens.green],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Frosted pill for labels sitting on top of the gradient hero.
class WeatherGlassChip extends StatelessWidget {
  final IconData? icon;
  final String label;

  const WeatherGlassChip({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded tinted tile holding the weather glyph.
class WeatherIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const WeatherIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

/// One secondary reading: icon + value + tiny label.
class WeatherMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const WeatherMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = highlight
        ? FamhubBrandTokens.orange
        : theme.textTheme.titleMedium?.color ?? Colors.black87;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: highlight
                    ? FamhubBrandTokens.orange
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calm "Updated earlier" / "Updated 5 min ago" indicator.
class WeatherFreshnessLabel extends StatelessWidget {
  final String label;

  const WeatherFreshnessLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Skeleton matching the panel it stands in for — compact inside dashboard
/// cards, hero-sized when it replaces the Weather page's gradient panel.
class WeatherSkeleton extends StatelessWidget {
  /// Compact variant used inside the Home / Farm Management cards.
  final bool compact;

  const WeatherSkeleton({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = BoxDecoration(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(compact ? 10 : 14),
    );
    final chip = BoxDecoration(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 44, height: 44, decoration: block),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 96, height: 22, decoration: block),
                      const SizedBox(height: 6),
                      Container(width: 140, height: 12, decoration: block),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Expanded(
                    child: Container(height: 28, decoration: block),
                  ),
                  if (i < 3) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 108, height: 26, decoration: chip),
              const Spacer(),
              Container(width: 116, height: 26, decoration: chip),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 132, height: 54, decoration: block),
                    const SizedBox(height: 10),
                    Container(width: 92, height: 16, decoration: block),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(height: 74, decoration: block),
                  ),
                  if (i < 2) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact "weather is not available" row (never blocks the surface).
class WeatherUnavailable extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenWeather;

  const WeatherUnavailable({
    super.key,
    this.message = 'Weather is not available for this location yet.',
    this.onOpenWeather,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
              Icons.cloud_off_outlined,
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
          if (onOpenWeather != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Open weather',
              onPressed: onOpenWeather,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact failure row with a retry action. No provider/technical detail.
class WeatherErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const WeatherErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FamhubBrandTokens.orange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 22,
              color: FamhubBrandTokens.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Weather is temporarily unavailable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
