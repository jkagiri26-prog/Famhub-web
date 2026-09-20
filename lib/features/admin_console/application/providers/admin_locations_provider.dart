/// ============================================================
/// ADMIN LOCATIONS PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// Bridges the Locations UI to the admin-safe services:
///   AdminLocationsService  → the 4 location RPCs
///   AdminGeographyService  → canonical countries / geography levels
///
/// The list query is immutable + equatable so Riverpod caches each
/// (search, country, level, parent, active, page) combination. All
/// filtering/pagination is server-side.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_location.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_geography_service.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_locations_service.dart';

final adminLocationsServiceProvider =
    Provider<AdminLocationsService>((ref) => AdminLocationsService());

final adminGeographyServiceProvider =
    Provider<AdminGeographyService>((ref) => AdminGeographyService());

class AdminLocationsQuery {
  final String? search;
  final String? countryId;
  final String? levelId;
  final String? parentId;
  final bool? isActive;
  final int page;
  final int pageSize;

  const AdminLocationsQuery({
    this.search,
    this.countryId,
    this.levelId,
    this.parentId,
    this.isActive,
    this.page = 0,
    this.pageSize = 25,
  });

  int get offset => page * pageSize;

  @override
  bool operator ==(Object other) =>
      other is AdminLocationsQuery &&
      other.search == search &&
      other.countryId == countryId &&
      other.levelId == levelId &&
      other.parentId == parentId &&
      other.isActive == isActive &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
        search,
        countryId,
        levelId,
        parentId,
        isActive,
        page,
        pageSize,
      );
}

final adminLocationsProvider =
    FutureProvider.family<AdminLocationsPage, AdminLocationsQuery>(
  (ref, query) async {
    final service = ref.watch(adminLocationsServiceProvider);
    final search = query.search?.trim();
    return service.listLocations(
      parentId: query.parentId,
      levelId: query.levelId,
      countryId: query.countryId,
      search: (search == null || search.isEmpty) ? null : search,
      isActive: query.isActive,
      limit: query.pageSize,
      offset: query.offset,
    );
  },
);

/// Canonical country list (read-only reference data).
final adminCountriesProvider = FutureProvider<List<AdminCountry>>((ref) async {
  return ref.watch(adminGeographyServiceProvider).listCountries();
});

/// Geography levels for a country (read-only reference data). Null/empty
/// country → all levels.
final adminGeographyLevelsProvider =
    FutureProvider.family<List<AdminGeographyLevel>, String?>(
  (ref, countryId) async {
    return ref
        .watch(adminGeographyServiceProvider)
        .listGeographyLevels(countryId: countryId);
  },
);

/// Bounded candidate parents for the Add/Edit form (same country + parent
/// level, max 100 = backend maximum). Never downloads the whole population.
final adminParentCandidatesProvider = FutureProvider.family<List<AdminLocation>,
    ({String? countryId, String? levelId})>((ref, args) async {
  final service = ref.watch(adminLocationsServiceProvider);
  final page = await service.listLocations(
    countryId: args.countryId,
    levelId: args.levelId,
    limit: 100,
    offset: 0,
  );
  return page.items;
});

// ============================================================
// ACTIONS (create / update / activate)
// ============================================================

final adminLocationsActionsProvider =
    Provider<AdminLocationsActions>((ref) => AdminLocationsActions(ref));

class AdminLocationsActions {
  final Ref _ref;

  AdminLocationsActions(this._ref);

  AdminLocationsService get _service => _ref.read(adminLocationsServiceProvider);

  Future<void> create({
    required String name,
    required String levelId,
    required String countryId,
    String? parentId,
    int? code,
  }) async {
    await _service.createLocation(
      name: name,
      levelId: levelId,
      countryId: countryId,
      parentId: parentId,
      code: code,
    );
    _ref.invalidate(adminLocationsProvider);
  }

  Future<void> update({
    required String locationId,
    required String name,
    required String levelId,
    required String? parentId,
    required String countryId,
    required int? code,
  }) async {
    await _service.updateLocation(
      locationId: locationId,
      name: name,
      levelId: levelId,
      parentId: parentId,
      countryId: countryId,
      code: code,
    );
    _ref.invalidate(adminLocationsProvider);
  }

  Future<void> setActive({
    required String locationId,
    required bool isActive,
  }) async {
    await _service.setLocationActive(
      locationId: locationId,
      isActive: isActive,
    );
    _ref.invalidate(adminLocationsProvider);
  }
}
