/// Export legacy registry for backward compatibility
library;
export 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart' show DashboardWidgetBuilder;

import 'package:flutter/widgets.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart' as wbr;

/// ============================================================
/// WIDGET REGISTRY (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/builders/ = presentation builders
///
/// ✅ Responsibilities:
///   - Map widgetKey strings to Flutter widget builders
///   - Support metadata for each registered widget
///   - Enable lazy widget resolution
///   - No switch statements, no hardcoded widget selection
///
/// ✅ Key Improvement over WidgetBuilderRegistry:
///   - Adds WidgetRegistration metadata
///   - Supports device visibility rules
///   - Supports section association
///   - Supports grouping for governance
///   - Enables runtime introspection
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Render widgets directly
///   - Import feature modules
///   - Reference providers
/// ============================================================
typedef DashboardWidgetBuilder = Widget Function();

/// ============================================================
/// WIDGET REGISTRATION (METADATA-DRIVEN)
/// ============================================================
///
/// Metadata for a registered dashboard widget.
/// Defines where and when a widget can appear.
/// ============================================================
class WidgetRegistration {
  /// Unique widget key
  final String widgetKey;

  /// Human-readable name
  final String displayName;

  /// Default section (overridable by backend)
  final String defaultSection;

  /// Whether this widget can appear on mobile
  final bool allowMobile;

  /// Whether this widget can appear on tablet
  final bool allowTablet;

  /// Whether this widget can appear on desktop
  final bool allowDesktop;

  /// Default width in grid units
  final int defaultWidth;

  /// Default height in grid units
  final int defaultHeight;

  /// Default refresh interval (seconds, 0 = none)
  final int defaultRefreshInterval;

  /// Whether this widget requires authentication
  final bool requiresAuth;

  const WidgetRegistration({
    required this.widgetKey,
    required this.displayName,
    this.defaultSection = 'default',
    this.allowMobile = true,
    this.allowTablet = true,
    this.allowDesktop = true,
    this.defaultWidth = 1,
    this.defaultHeight = 1,
    this.defaultRefreshInterval = 0,
    this.requiresAuth = true,
  });
}

/// ============================================================
/// WIDGET REGISTRY (STATIC REGISTRATION)
/// ============================================================
///
/// Enterprise-grade widget registry.
/// Each feature module registers its widgets here at startup.
/// The dashboard renderer resolves widgets by key lookup only.
///
/// ✅ No switch statements
/// ✅ No hardcoded widget references
/// ✅ Fully backend-driven (backend provides widgetKey)
/// ============================================================
class WidgetRegistry {
  /// Internal registry: widgetKey → builder
  static final Map<String, DashboardWidgetBuilder> _builders = {};

  /// Internal registry: widgetKey → metadata
  static final Map<String, WidgetRegistration> _metadata = {};

  /// ============================================================
  /// REGISTER WIDGET
  /// ============================================================
  ///
  /// Register a widget builder and its metadata.
  /// Throws if widgetKey is already registered (prevents conflicts).
  /// ============================================================
  static void register({
    required String widgetKey,
    required DashboardWidgetBuilder builder,
    WidgetRegistration? metadata,
  }) {
    if (_builders.containsKey(widgetKey)) {
      throw Exception(
        'WidgetRegistry: Builder already registered for "$widgetKey". '
        'Each widget key must be unique.',
      );
    }

    _builders[widgetKey] = builder;

    if (metadata != null) {
      _metadata[widgetKey] = metadata;
    } else {
      _metadata[widgetKey] = WidgetRegistration(
        widgetKey: widgetKey,
        displayName: widgetKey,
      );
    }
  }

  /// ============================================================
  /// DEREGISTER WIDGET
  /// ============================================================
  ///
  /// Remove a widget from the registry.
  /// Useful for module unload or hot reload scenarios.
  /// ============================================================
  static void deregister(String widgetKey) {
    _builders.remove(widgetKey);
    _metadata.remove(widgetKey);
  }

  /// ============================================================
  /// RESOLVE BUILDER
  /// ============================================================
  ///
  /// Returns the builder for a widget key, or null if not found.
  /// ============================================================
  static DashboardWidgetBuilder? resolve(String widgetKey) {
    return _builders[widgetKey];
  }

  /// ============================================================
  /// GET METADATA
  /// ============================================================
  ///
  /// Returns the registration metadata for a widget key.
  /// ============================================================
  static WidgetRegistration? getMetadata(String widgetKey) {
    return _metadata[widgetKey];
  }

  /// ============================================================
  /// CHECK REGISTRATION
  /// ============================================================
  static bool isRegistered(String widgetKey) {
    return _builders.containsKey(widgetKey);
  }

  /// ============================================================
  /// LIST ALL REGISTERED KEYS
  /// ============================================================
  static List<String> get registeredKeys =>
      _builders.keys.toList();

  /// ============================================================
  /// LIST ALL METADATA
  /// ============================================================
  static List<WidgetRegistration> get allMetadata =>
      _metadata.values.toList();

  /// ============================================================
  /// CLEAR (TESTING / HOT RELOAD)
  /// ============================================================
  static void clear() {
    _builders.clear();
    _metadata.clear();
  }

  /// ============================================================
  /// LEGACY COMPATIBILITY
  /// ============================================================
  ///
  /// Bridge to existing WidgetBuilderRegistry.
  /// Ensures backward compatibility during migration.
  /// ============================================================
  static void registerLegacy(String widgetKey) {
    if (_builders.containsKey(widgetKey)) return;

    final legacyBuilder = wbr.WidgetBuilderRegistry.resolve(widgetKey);
    if (legacyBuilder != null) {
      _builders[widgetKey] = legacyBuilder;
      _metadata[widgetKey] = WidgetRegistration(
        widgetKey: widgetKey,
        displayName: widgetKey,
      );
    }
  }

  /// ============================================================
  /// BRIDGE ALL LEGACY
  /// ============================================================
  static void bridgeAllLegacy() {
    for (final key in wbr.WidgetBuilderRegistry.registeredKeys) {
      registerLegacy(key);
    }
  }
}
