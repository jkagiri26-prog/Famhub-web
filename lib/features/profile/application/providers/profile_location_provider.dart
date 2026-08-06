/// ============================================================
/// PROFILE LOCATION PROVIDER — Geography hierarchy management
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/providers/ = presentation layer
///
/// ✅ Responsibilities:
///   - Receive country from SessionCountryProvider
///   - Load geography hierarchy levels for the country
///   - Load child locations for the selected parent
///   - Maintain selected location state
///   - Loading / error state
///   - Cache geography levels and loaded location lists
///
/// ❌ Does NOT:
///   - Determine the country (receives it from SessionCountryProvider)
///   - Contain UI logic
///   - Call backend endpoints outside core schema
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';

/// ────────────────────────────────────────────────────────────
/// Models
/// ────────────────────────────────────────────────────────────

/// A single geography level (e.g. County, Sub-County, Ward).
class GeographyLevel {
  final String id;
  final String levelName;
  final int levelOrder;

  const GeographyLevel({
    required this.id,
    required this.levelName,
    required this.levelOrder,
  });

  factory GeographyLevel.fromRow(Map<String, dynamic> row) {
    return GeographyLevel(
      id: row['id'] as String,
      levelName: row['level_name'] as String,
      levelOrder: row['level_order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level_name': levelName,
        'level_order': levelOrder,
      };
}

/// A single location (e.g. Nairobi, Westlands).
class GeoLocation {
  final String id;
  final String name;
  final String? levelId;
  final String? parentId;

  const GeoLocation({
    required this.id,
    required this.name,
    this.levelId,
    this.parentId,
  });

  factory GeoLocation.fromRow(Map<String, dynamic> row) {
    return GeoLocation(
      id: row['id'] as String,
      name: row['name'] as String,
      levelId: row['level_id'] as String?,
      parentId: row['parent_id'] as String?,
    );
  }
}

/// ────────────────────────────────────────────────────────────
/// State
/// ────────────────────────────────────────────────────────────
class ProfileLocationState {
  /// The geography levels for the current country, ordered by levelOrder.
  final List<GeographyLevel> levels;

  /// Whether levels are being loaded.
  final bool isLoadingLevels;

  /// Error when loading levels.
  final String? levelsError;

  /// Map from levelId to cached locations.
  /// Key = levelId (or "levelId|parentId" for child queries)
  final Map<String, List<GeoLocation>> locationCache;

  /// Map from levelId to loading state.
  final Set<String> loadingLocationKeys;

  /// Map from levelId to error state.
  final Map<String, String> locationErrors;

  /// Currently selected location per level index.
  /// Key = level index (0-based), Value = GeoLocation
  final Map<int, GeoLocation> selectedLocations;

  const ProfileLocationState({
    this.levels = const [],
    this.isLoadingLevels = false,
    this.levelsError,
    this.locationCache = const {},
    this.loadingLocationKeys = const {},
    this.locationErrors = const {},
    this.selectedLocations = const {},
  });

  ProfileLocationState copyWith({
    List<GeographyLevel>? levels,
    bool? isLoadingLevels,
    String? levelsError,
    bool clearLevelsError = false,
    Map<String, List<GeoLocation>>? locationCache,
    Set<String>? loadingLocationKeys,
    Map<String, String>? locationErrors,
    Map<int, GeoLocation>? selectedLocations,
  }) {
    return ProfileLocationState(
      levels: levels ?? this.levels,
      isLoadingLevels: isLoadingLevels ?? this.isLoadingLevels,
      levelsError:
          clearLevelsError ? null : levelsError ?? this.levelsError,
      locationCache: locationCache ?? this.locationCache,
      loadingLocationKeys: loadingLocationKeys ?? this.loadingLocationKeys,
      locationErrors: locationErrors ?? this.locationErrors,
      selectedLocations: selectedLocations ?? this.selectedLocations,
    );
  }

  /// Convenience: build a cache key for root-level locations.
  static String rootCacheKey(String levelId) => levelId;

  /// Convenience: build a cache key for child locations.
  static String childCacheKey(String levelId, String parentId) =>
      '$levelId|$parentId';
}

/// ────────────────────────────────────────────────────────────
/// Controller
/// ────────────────────────────────────────────────────────────
class ProfileLocationController extends Notifier<ProfileLocationState> {
  @override
  ProfileLocationState build() {
    return const ProfileLocationState();
  }

  // ═══════════════════════════════════════════════
  // CACHE PERSISTENCE KEYS
  // ═══════════════════════════════════════════════
  static const _cachePrefixLevels = 'famhub_geo_levels_';

  /// ── Initialize: loads geography levels for the given country ──
  Future<void> initialize(String countryId) async {
    if (countryId.isEmpty) return;

    state = state.copyWith(isLoadingLevels: true, clearLevelsError: true);

    try {
      // Try cache first
      final cached = await _loadLevelsFromCache(countryId);
      if (cached.isNotEmpty) {
        state = state.copyWith(
          levels: cached,
          isLoadingLevels: false,
        );
        // Auto-fetch root-level locations for the first level
        if (cached.isNotEmpty) {
          await loadLocations(levelIndex: 0, parentId: null);
        }
        return;
      }

      // Fetch from backend
      final supabase = SupabaseService.instance;
      final response = await supabase
          .from('geography_levels', schema: 'core')
          .select('id, level_name, level_order')
          .eq('country_id', countryId)
          .order('level_order', ascending: true);

      final levels = (response as List)
          .map((r) => GeographyLevel.fromRow(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        levels: levels,
        isLoadingLevels: false,
      );

      // Cache for later
      _saveLevelsToCache(countryId, levels);

      // Auto-fetch root-level locations for the first level
      if (levels.isNotEmpty) {
        await loadLocations(levelIndex: 0, parentId: null);
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingLevels: false,
        levelsError: 'Failed to load geography levels',
      );
    }
  }

  /// ── Load locations for a given level (by index) ──
  /// [levelIndex] — index into the levels list.
  /// [parentId] — parent location ID, or null for root level.
  Future<void> loadLocations({
    required int levelIndex,
    String? parentId,
  }) async {
    if (levelIndex >= state.levels.length) return;

    final level = state.levels[levelIndex];
    final cacheKey = parentId == null
        ? ProfileLocationState.rootCacheKey(level.id)
        : ProfileLocationState.childCacheKey(level.id, parentId);

    // Already cached?
    if (state.locationCache.containsKey(cacheKey)) return;

    // Already loading?
    if (state.loadingLocationKeys.contains(cacheKey)) return;

    // Mark loading
    state = state.copyWith(
      loadingLocationKeys: {...state.loadingLocationKeys, cacheKey},
    );

    try {
      final supabase = SupabaseService.instance;

      // Build the query. Use .filter() for IS NULL check on root-level
      // locations; .eq() for child lookups.  .filter returns a
      // PostgrestFilterBuilder which also supports .eq, so the order
      // is safe.
      final baseQuery = supabase
          .from('locations', schema: 'core')
          .select('id, name, level_id, parent_id')
          .eq('level_id', level.id);

      final filteredQuery = (parentId == null || parentId.trim().isEmpty)
          ? baseQuery.filter('parent_id', 'is', null)
          : baseQuery.eq('parent_id', parentId);

      // .order() is the LAST operation (returns PostgrestTransformBuilder)
      final response = await filteredQuery.order('name');

      final locations = (response as List)
          .map((r) => GeoLocation.fromRow(r as Map<String, dynamic>))
          .toList();

      final newCache =
          Map<String, List<GeoLocation>>.from(state.locationCache);
      newCache[cacheKey] = locations;

      final newLoading =
          Set<String>.from(state.loadingLocationKeys);
      newLoading.remove(cacheKey);

      state = state.copyWith(
        locationCache: newCache,
        loadingLocationKeys: newLoading,
      );
    } catch (e) {
      final newLoading =
          Set<String>.from(state.loadingLocationKeys);
      newLoading.remove(cacheKey);

      final newErrors =
          Map<String, String>.from(state.locationErrors);
      newErrors[cacheKey] = 'Failed to load ${level.levelName}';

      state = state.copyWith(
        loadingLocationKeys: newLoading,
        locationErrors: newErrors,
      );
    }
  }

  /// ── Refresh levels for the given country (call on retry) ──
  Future<void> refresh(String countryId) async {
    state = const ProfileLocationState();
    await initialize(countryId);
  }

  /// ── Select a location for a given level ──
  void selectLocation(int levelIndex, GeoLocation? location) {
    final newSelected =
        Map<int, GeoLocation>.from(state.selectedLocations);
    if (location == null) {
      newSelected.remove(levelIndex);
      // Clear all deeper selections
      newSelected.removeWhere((key, _) => key > levelIndex);
    } else {
      newSelected[levelIndex] = location;
      // Clear all deeper selections
      newSelected.removeWhere((key, _) => key > levelIndex);
    }
    state = state.copyWith(selectedLocations: newSelected);

    // Trigger child location loading for the next level
    if (location != null && levelIndex + 1 < state.levels.length) {
      loadLocations(levelIndex: levelIndex + 1, parentId: location.id);
    }
  }

  /// ── Get the list of selected location IDs for profile saving ──
  List<SelectedLocationEntry> get selectedEntries {
    final entries = <SelectedLocationEntry>[];
    for (var i = 0; i < state.levels.length; i++) {
      final loc = state.selectedLocations[i];
      if (loc != null) {
        entries.add(SelectedLocationEntry(
          levelName: state.levels[i].levelName,
          locationId: loc.id,
          locationName: loc.name,
        ));
      }
    }
    return entries;
  }

  // ═══════════════════════════════════════════════
  // CACHE HELPERS
  // ═══════════════════════════════════════════════

  static String _cacheKeyLevels(String countryId) =>
      '$_cachePrefixLevels$countryId';

  Future<List<GeographyLevel>> _loadLevelsFromCache(
      String countryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKeyLevels(countryId));
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => GeographyLevel(
                id: e['id'] as String,
                levelName: e['level_name'] as String,
                levelOrder: e['level_order'] as int,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLevelsToCache(
      String countryId, List<GeographyLevel> levels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = levels.map((l) => l.toJson()).toList();
      await prefs.setString(
          _cacheKeyLevels(countryId), jsonEncode(encoded));
    } catch (_) {
      // Best-effort cache
    }
  }
}

/// ────────────────────────────────────────────────────────────
/// Exported entry for profile saving
/// ────────────────────────────────────────────────────────────
class SelectedLocationEntry {
  final String levelName;
  final String locationId;
  final String locationName;

  const SelectedLocationEntry({
    required this.levelName,
    required this.locationId,
    required this.locationName,
  });
}

/// ────────────────────────────────────────────────────────────
/// Providers
/// ────────────────────────────────────────────────────────────

final profileLocationProvider =
    NotifierProvider<ProfileLocationController, ProfileLocationState>(
  ProfileLocationController.new,
);

/// Init helper — called once when the page first builds and
/// the country ID becomes available.
final profileLocationInitProvider =
    FutureProvider.family<void, String>((ref, countryId) async {
  if (countryId.isEmpty) return;
  await ref.read(profileLocationProvider.notifier).initialize(countryId);
});

/// Whether the location hierarchy is ready to display.
final isLocationHierarchyReadyProvider = Provider<bool>((ref) {
  final s = ref.watch(profileLocationProvider);
  return s.levels.isNotEmpty;
});