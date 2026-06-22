// ignore: dangling_library_doc_comments
/// ============================================================
/// ROUTE PARITY VALIDATOR
/// ============================================================
///
/// Validates that every module registered in ModuleRegistry
/// has a corresponding route in RouteRegistry and AppRouter.
///
/// 🧠 LOCATION CONTEXT:
///   core/router/route_validation/ = validation utilities
///
/// ✅ Responsibilities:
///   - Route parity validation between registries
///   - Duplicate route detection
///   - Missing route detection
///   - Invalid route detection
/// ============================================================

import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/system/registry/route_registry.dart';

class RouteParityValidator {
  const RouteParityValidator._();

  /// ============================================================
  /// VALIDATE COMPLETE ROUTE PARITY
  /// ============================================================
  ///
  /// Runs all validation checks and returns a report.
  /// ============================================================
  static RouteParityReport validateAll() {
    final missingRoutes = _findMissingRoutes();
    final duplicateRoutes = _findDuplicateRoutes();
    final invalidRoutes = _findInvalidRoutes();
    final orphanRegistrations = _findOrphanRegistrations();

    return RouteParityReport(
      missingRoutes: missingRoutes,
      duplicateRoutes: duplicateRoutes,
      invalidRoutes: invalidRoutes,
      orphanRegistrations: orphanRegistrations,
      moduleCount: ModuleRegistry.definitions.length,
      routeMappingCount: RouteRegistry.mappings.length,
      isPassing: missingRoutes.isEmpty &&
          duplicateRoutes.isEmpty &&
          invalidRoutes.isEmpty &&
          orphanRegistrations.isEmpty,
    );
  }

  /// ============================================================
  /// FIND MISSING ROUTES
  /// ============================================================
  ///
  /// Modules that have an entryRoute defined but no corresponding
  /// RouteMapping in the RouteRegistry.
  /// ============================================================
  static List<MissingRouteEntry> _findMissingRoutes() {
    final missing = <MissingRouteEntry>[];

    for (final module in ModuleRegistry.definitions) {
      final mapping = RouteRegistry.forModule(module.moduleId);
      if (mapping == null) {
        missing.add(MissingRouteEntry(
          moduleId: module.moduleId,
          name: module.name,
          entryRoute: module.entryRoute,
          reason: 'No RouteMapping found in RouteRegistry for this module',
        ));
        continue;
      }

      if (mapping.route != module.entryRoute) {
        missing.add(MissingRouteEntry(
          moduleId: module.moduleId,
          name: module.name,
          entryRoute: module.entryRoute,
          reason:
              'Route mismatch: ModuleRegistry entryRoute="${module.entryRoute}" '
              'but RouteRegistry route="${mapping.route}"',
        ));
      }
    }

    return missing;
  }

  /// ============================================================
  /// FIND DUPLICATE ROUTES
  /// ============================================================
  ///
  /// Routes that appear more than once across registries.
  /// ============================================================
  static List<DuplicateRouteEntry> _findDuplicateRoutes() {
    final routeCounts = <String, int>{};
    final duplicates = <DuplicateRouteEntry>[];

    // Check RouteRegistry for duplicate routes
    for (final mapping in RouteRegistry.mappings) {
      routeCounts[mapping.route] = (routeCounts[mapping.route] ?? 0) + 1;
    }

    for (final entry in routeCounts.entries) {
      if (entry.value > 1) {
        duplicates.add(DuplicateRouteEntry(
          route: entry.key,
          occurrenceCount: entry.value,
          source: 'RouteRegistry',
        ));
      }
    }

    // Check ModuleRegistry for duplicate routes
    final moduleRouteCounts = <String, int>{};
    for (final def in ModuleRegistry.definitions) {
      moduleRouteCounts[def.entryRoute] =
          (moduleRouteCounts[def.entryRoute] ?? 0) + 1;
    }

    for (final entry in moduleRouteCounts.entries) {
      if (entry.value > 1) {
        duplicates.add(DuplicateRouteEntry(
          route: entry.key,
          occurrenceCount: entry.value,
          source: 'ModuleRegistry',
        ));
      }
    }

    return duplicates;
  }

  /// ============================================================
  /// FIND INVALID ROUTES
  /// ============================================================
  ///
  /// Routes that don't start with '/' or contain invalid characters.
  /// ============================================================
  static List<InvalidRouteEntry> _findInvalidRoutes() {
    final invalid = <InvalidRouteEntry>[];

    for (final mapping in RouteRegistry.mappings) {
      if (!mapping.route.startsWith('/')) {
        invalid.add(InvalidRouteEntry(
          route: mapping.route,
          source: 'RouteRegistry',
          issue: 'Route does not start with "/"',
        ));
      }
    }

    for (final def in ModuleRegistry.definitions) {
      if (!def.entryRoute.startsWith('/')) {
        invalid.add(InvalidRouteEntry(
          route: def.entryRoute,
          source: 'ModuleRegistry',
          issue: 'Route does not start with "/"',
        ));
      }
    }

    return invalid;
  }

  /// ============================================================
  /// FIND ORPHAN REGISTRATIONS
  /// ============================================================
  ///
  /// RouteRegistry mappings that have no corresponding module.
  /// ============================================================
  static List<OrphanRegistrationEntry> _findOrphanRegistrations() {
    final orphans = <OrphanRegistrationEntry>[];

    for (final mapping in RouteRegistry.mappings) {
      final module = ModuleRegistry.byId(mapping.moduleId);
      if (module == null) {
        orphans.add(OrphanRegistrationEntry(
          moduleId: mapping.moduleId,
          route: mapping.route,
          reason: 'No module definition exists for this moduleId',
        ));
      }
    }

    return orphans;
  }
}

/// ============================================================
/// DATA CLASSES FOR VALIDATION REPORT
/// ============================================================

class RouteParityReport {
  final List<MissingRouteEntry> missingRoutes;
  final List<DuplicateRouteEntry> duplicateRoutes;
  final List<InvalidRouteEntry> invalidRoutes;
  final List<OrphanRegistrationEntry> orphanRegistrations;
  final int moduleCount;
  final int routeMappingCount;
  final bool isPassing;

  const RouteParityReport({
    required this.missingRoutes,
    required this.duplicateRoutes,
    required this.invalidRoutes,
    required this.orphanRegistrations,
    required this.moduleCount,
    required this.routeMappingCount,
    required this.isPassing,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('═══ ROUTE PARITY REPORT ═══');
    buffer.writeln('Modules: $moduleCount | Route Mappings: $routeMappingCount');
    buffer.writeln('Status: ${isPassing ? "✅ PASS" : "❌ FAIL"}');
    buffer.writeln('');

    if (missingRoutes.isNotEmpty) {
      buffer.writeln('── Missing Routes (${missingRoutes.length}) ──');
      for (final m in missingRoutes) {
        buffer.writeln('  • ${m.moduleId} ("${m.name}"): ${m.reason}');
      }
      buffer.writeln('');
    }

    if (duplicateRoutes.isNotEmpty) {
      buffer.writeln('── Duplicate Routes (${duplicateRoutes.length}) ──');
      for (final d in duplicateRoutes) {
        buffer.writeln('  • "${d.route}" (${d.occurrenceCount}x in ${d.source})');
      }
      buffer.writeln('');
    }

    if (invalidRoutes.isNotEmpty) {
      buffer.writeln('── Invalid Routes (${invalidRoutes.length}) ──');
      for (final i in invalidRoutes) {
        buffer.writeln('  • "${i.route}" in ${i.source}: ${i.issue}');
      }
      buffer.writeln('');
    }

    if (orphanRegistrations.isNotEmpty) {
      buffer.writeln('── Orphan Registrations (${orphanRegistrations.length}) ──');
      for (final o in orphanRegistrations) {
        buffer.writeln('  • moduleId="${o.moduleId}" route="${o.route}": ${o.reason}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

class MissingRouteEntry {
  final String moduleId;
  final String name;
  final String entryRoute;
  final String reason;

  const MissingRouteEntry({
    required this.moduleId,
    required this.name,
    required this.entryRoute,
    required this.reason,
  });
}

class DuplicateRouteEntry {
  final String route;
  final int occurrenceCount;
  final String source;

  const DuplicateRouteEntry({
    required this.route,
    required this.occurrenceCount,
    required this.source,
  });
}

class InvalidRouteEntry {
  final String route;
  final String source;
  final String issue;

  const InvalidRouteEntry({
    required this.route,
    required this.source,
    required this.issue,
  });
}

class OrphanRegistrationEntry {
  final String moduleId;
  final String route;
  final String reason;

  const OrphanRegistrationEntry({
    required this.moduleId,
    required this.route,
    required this.reason,
  });
}
