/// ============================================================
/// WEATHER LOCATION PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/application/providers/ = weather application layer
///
/// ✅ Responsibilities:
///   - Reuse the FAMHUB canonical location architecture (`core.locations`)
///   - Derive a weather target from the selected farm's canonical ids
///   - Fall back to the signed-in user's profile location
///   - Remember an explicit user choice from the Weather page selector
///
/// ❌ Does NOT:
///   - Create WeatherLocation / duplicate county-sub-county hierarchies
///   - Introduce a weather-specific location table or model hierarchy
///   - Parse `farm_management.farms.geo_coordinates` (order unknown)
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';

/// `users.profiles` canonical location columns, finest level first.
const List<String> profileLocationColumns = <String>[
  'level_7_location_id',
  'level_6_location_id',
  'level_5_location_id',
  'level_4_location_id',
  'level_3_location_id',
  'level_2_location_id',
];

/// A selectable weather place: a canonical `core.locations` id plus a label.
///
/// Lightweight UI model only — the canonical hierarchy stays in
/// `core.locations`; nothing weather-specific is stored.
class WeatherLocationCandidate {
  final WeatherRequestTarget target;
  final String label;

  /// `farm` | `profile` | `selected_farm`
  final String source;

  const WeatherLocationCandidate({
    required this.target,
    required this.label,
    required this.source,
  });

  String? get locationId => target.locationId;

  String get key => locationId ?? '${target.latitude},${target.longitude}';

  @override
  bool operator ==(Object other) =>
      other is WeatherLocationCandidate &&
      other.target == target &&
      other.label == label &&
      other.source == source;

  @override
  int get hashCode => Object.hash(target, label, source);
}

/// Build a candidate from a farm row's canonical location ids.
///
/// The most granular available id wins. `geo_coordinates` is never read.
WeatherLocationCandidate? farmWeatherCandidate(FarmEntity farm) {
  final locationId = _firstNonEmpty([
    farm.wardId,
    farm.subCountyId,
    farm.countyId,
  ]);
  if (locationId == null) return null;
  return WeatherLocationCandidate(
    target: WeatherRequestTarget.fromLocationId(locationId),
    label: farm.farmName,
    source: 'farm',
  );
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// All places the signed-in user could ask weather for, best first.
final weatherLocationCandidatesProvider =
    Provider<List<WeatherLocationCandidate>>((ref) {
  final hierarchy = ref.watch(hierarchyProvider);
  final profile = ref.watch(sessionProvider).profile ?? const {};

  final candidates = <WeatherLocationCandidate>[];
  final seen = <String>{};

  void add(WeatherLocationCandidate? candidate) {
    if (candidate == null) return;
    if (!seen.add(candidate.key)) return;
    candidates.add(candidate);
  }

  // 1. Farm currently selected in the hierarchy.
  final selectedFarm = hierarchy.entity;
  if (selectedFarm != null) add(farmWeatherCandidate(selectedFarm));

  // 2. The user's own canonical profile location.
  for (final column in profileLocationColumns) {
    final raw = profile[column];
    final locationId = raw is String ? raw.trim() : null;
    if (locationId == null || locationId.isEmpty) continue;
    add(WeatherLocationCandidate(
      target: WeatherRequestTarget.fromLocationId(locationId),
      label: 'My location',
      source: 'profile',
    ));
    break;
  }

  // 3. Every other farm the user can see.
  for (final farm in hierarchy.farms) {
    if (selectedFarm != null && farm.id == selectedFarm.id) continue;
    add(farmWeatherCandidate(farm));
  }

  return candidates;
});

/// Explicit selection made from the Weather page location selector.
class WeatherLocationController extends Notifier<WeatherLocationCandidate?> {
  @override
  WeatherLocationCandidate? build() => null;

  void select(WeatherLocationCandidate? candidate) => state = candidate;

  void clear() => state = null;
}

final weatherSelectedLocationProvider =
    NotifierProvider<WeatherLocationController, WeatherLocationCandidate?>(
  WeatherLocationController.new,
);

/// The location the shared weather UI should resolve.
///
/// An explicit selection wins; otherwise the best derived candidate.
final weatherLocationProvider = Provider<WeatherLocationCandidate?>((ref) {
  final selected = ref.watch(weatherSelectedLocationProvider);
  if (selected != null) return selected;
  final candidates = ref.watch(weatherLocationCandidatesProvider);
  return candidates.isEmpty ? null : candidates.first;
});

/// `true` while the session (and therefore profile locations) is still
/// restoring — weather should show a skeleton, not "unavailable".
final weatherLocationResolvingProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).status == SessionStatus.initializing;
});

/// Canonical display name for a `core.locations` id.
///
/// Cached per id (non-auto-dispose family) — this is location metadata,
/// not weather data.
final locationDisplayNameProvider = FutureProvider.family<String?, String>(
  (ref, locationId) async {
    if (locationId.trim().isEmpty) return null;
    try {
      final row = await SupabaseService.instance
          .from('locations', schema: 'core')
          .select('name')
          .eq('id', locationId)
          .maybeSingle();
      final name = row?['name']?.toString();
      return (name == null || name.trim().isEmpty) ? null : name.trim();
    } catch (_) {
      return null;
    }
  },
);

/// Human label for the location currently in use.
final weatherLocationLabelProvider = Provider<String?>((ref) {
  final candidate = ref.watch(weatherLocationProvider);
  if (candidate == null) return null;
  if (candidate.source != 'profile') return candidate.label;

  final locationId = candidate.locationId;
  if (locationId == null) return candidate.label;
  final resolved = ref.watch(locationDisplayNameProvider(locationId));
  return resolved.whenOrNull(data: (name) => name ?? candidate.label) ??
      candidate.label;
});
