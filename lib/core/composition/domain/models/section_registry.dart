/// ============================================================
/// SECTION REGISTRY (UI COMPOSITION CONFIGURATION)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain layer
///
/// ✅ RESPONSIBILITY:
///   Resolve section presentation metadata (display names, icons,
///   default priority/layout hints) from section keys.
///
///   Section keys come from the backend (system.modules), but their
///   PRESENTATION is a UI composition concern, not module governance.
///   This registry decouples section metadata from module governance.
///
/// 🔄 DATA FLOW:
///   system.modules.section (backend) → SectionRegistry (UI layer)
///                                          ↓
///                                   displayName, icon, order, layout
///
/// 🆕 ADDING A NEW SECTION:
///   When a new module with a new section key is added in the backend:
///   1. Add a SectionDefinition here with display name and icon
///   2. No UI code changes needed — the renderers consume from here
///   3. Unknown sections → fallback to generic title/icon
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - SectionRegistry is a COMPOSITION concern, not GOVERNANCE
///   - Backend owns: section key (as part of module metadata)
///   - UI owns: section display name, icon, layout hints
///   - Unknown sections get a safe fallback, never crash
///
/// ❌ Does NOT:
///   - Duplicate backend governance (enable/disable, permissions, etc.)
///   - Import feature modules
///   - Perform access control
///   - Render widgets
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SECTION DEFINITION
/// ============================================================
///
/// Presentation metadata for a dashboard/home section.
/// All fields have defaults — no field is required.
/// ============================================================
class SectionDefinition {
  /// The section key from backend (e.g. 'farm', 'marketplace', 'finance')
  final String sectionKey;

  /// Human-readable display name (e.g. 'Farm Overview', 'Marketplace')
  final String displayName;

  /// Material icon data for the section header
  final IconData icon;

  /// Default display order (lower = earlier)
  final int displayOrder;

  /// Default layout style: 'grid', 'carousel', 'stacked'
  final String layoutStyle;

  /// Maximum widgets to show in this section (0 = unlimited)
  final int maxWidgets;

  /// Whether this section supports carousel layout when >4 items
  final bool supportsCarousel;

  const SectionDefinition({
    required this.sectionKey,
    required this.displayName,
    required this.icon,
    this.displayOrder = 50,
    this.layoutStyle = 'grid',
    this.maxWidgets = 0,
    this.supportsCarousel = false,
  });
}

/// ============================================================
/// SECTION REGISTRY
/// ============================================================
///
/// Static catalog of all known section definitions.
/// Unknown section keys are handled via fallback.
/// ============================================================
class SectionRegistry {
  /// ── KNOWN SECTION DEFINITIONS ──
  static const List<SectionDefinition> _definitions = [
    SectionDefinition(
      sectionKey: 'farm',
      displayName: 'Farm Overview',
      icon: Icons.agriculture_outlined,
      displayOrder: 1,
      layoutStyle: 'grid',
    ),
    SectionDefinition(
      sectionKey: 'farming',
      displayName: 'Farm Overview',
      icon: Icons.agriculture_outlined,
      displayOrder: 1,
      layoutStyle: 'grid',
    ),
    SectionDefinition(
      sectionKey: 'marketplace',
      displayName: 'Marketplace',
      icon: Icons.store_outlined,
      displayOrder: 2,
      supportsCarousel: true,
    ),
    SectionDefinition(
      sectionKey: 'market',
      displayName: 'Marketplace',
      icon: Icons.store_outlined,
      displayOrder: 2,
      supportsCarousel: true,
    ),
    SectionDefinition(
      sectionKey: 'finance',
      displayName: 'Finance',
      icon: Icons.account_balance_outlined,
      displayOrder: 3,
    ),
    SectionDefinition(
      sectionKey: 'financial',
      displayName: 'Finance',
      icon: Icons.account_balance_outlined,
      displayOrder: 3,
    ),
    SectionDefinition(
      sectionKey: 'financing',
      displayName: 'Finance',
      icon: Icons.account_balance_outlined,
      displayOrder: 3,
    ),
    SectionDefinition(
      sectionKey: 'weather',
      displayName: 'Weather',
      icon: Icons.wb_sunny_outlined,
      displayOrder: 4,
    ),
    SectionDefinition(
      sectionKey: 'analytics',
      displayName: 'Analytics',
      icon: Icons.insights_outlined,
      displayOrder: 5,
    ),
    SectionDefinition(
      sectionKey: 'insights',
      displayName: 'Analytics',
      icon: Icons.insights_outlined,
      displayOrder: 5,
    ),
    SectionDefinition(
      sectionKey: 'community',
      displayName: 'Community',
      icon: Icons.people_outline,
      displayOrder: 6,
    ),
    SectionDefinition(
      sectionKey: 'connect',
      displayName: 'Community',
      icon: Icons.people_outline,
      displayOrder: 6,
    ),
    SectionDefinition(
      sectionKey: 'social',
      displayName: 'Community',
      icon: Icons.people_outline,
      displayOrder: 6,
    ),
    SectionDefinition(
      sectionKey: 'knowledge',
      displayName: 'Knowledge',
      icon: Icons.school_outlined,
      displayOrder: 7,
      supportsCarousel: true,
    ),
    SectionDefinition(
      sectionKey: 'education',
      displayName: 'Knowledge',
      icon: Icons.school_outlined,
      displayOrder: 7,
    ),
    SectionDefinition(
      sectionKey: 'learning',
      displayName: 'Knowledge',
      icon: Icons.school_outlined,
      displayOrder: 7,
    ),
    SectionDefinition(
      sectionKey: 'logistics',
      displayName: 'Logistics',
      icon: Icons.local_shipping_outlined,
      displayOrder: 8,
    ),
    SectionDefinition(
      sectionKey: 'supply_chain',
      displayName: 'Logistics',
      icon: Icons.local_shipping_outlined,
      displayOrder: 8,
    ),
    SectionDefinition(
      sectionKey: 'supplychain',
      displayName: 'Logistics',
      icon: Icons.local_shipping_outlined,
      displayOrder: 8,
    ),
    SectionDefinition(
      sectionKey: 'traceability',
      displayName: 'Traceability',
      icon: Icons.track_changes_outlined,
      displayOrder: 9,
    ),
    SectionDefinition(
      sectionKey: 'trace',
      displayName: 'Traceability',
      icon: Icons.track_changes_outlined,
      displayOrder: 9,
    ),
    SectionDefinition(
      sectionKey: 'carbon',
      displayName: 'Sustainability',
      icon: Icons.eco_outlined,
      displayOrder: 10,
    ),
    SectionDefinition(
      sectionKey: 'sustainability',
      displayName: 'Sustainability',
      icon: Icons.eco_outlined,
      displayOrder: 10,
    ),
    SectionDefinition(
      sectionKey: 'opportunities',
      displayName: 'Opportunities',
      icon: Icons.trending_up_outlined,
      displayOrder: 11,
      supportsCarousel: true,
    ),
    SectionDefinition(
      sectionKey: 'growth',
      displayName: 'Opportunities',
      icon: Icons.trending_up_outlined,
      displayOrder: 11,
    ),
    SectionDefinition(
      sectionKey: 'profile',
      displayName: 'Profile',
      icon: Icons.person_outline,
      displayOrder: 12,
    ),
    SectionDefinition(
      sectionKey: 'general',
      displayName: 'All Services',
      icon: Icons.dashboard_outlined,
      displayOrder: 999,
    ),
    SectionDefinition(
      sectionKey: 'default',
      displayName: 'All Services',
      icon: Icons.dashboard_outlined,
      displayOrder: 999,
    ),
    SectionDefinition(
      sectionKey: 'admin',
      displayName: 'Administration',
      icon: Icons.admin_panel_settings_outlined,
      displayOrder: 99,
    ),
    SectionDefinition(
      sectionKey: 'administration',
      displayName: 'Administration',
      icon: Icons.admin_panel_settings_outlined,
      displayOrder: 99,
    ),
  ];

  /// ── FALLBACK — used when section key is unknown ──
  static const SectionDefinition _fallback = SectionDefinition(
    sectionKey: 'unknown',
    displayName: 'Services',
    icon: Icons.widgets_outlined,
    displayOrder: 50,
  );

  /// ============================================================
  /// GET SECTION DEFINITION
  /// ============================================================
  ///
  /// Returns the SectionDefinition for the given section key.
  /// If the key is unknown, returns a safe fallback with
  /// a generic title and icon (never crashes).
  /// ============================================================
  static SectionDefinition get(String sectionKey) {
    final lowerKey = sectionKey.toLowerCase().trim();
    for (final def in _definitions) {
      if (def.sectionKey == lowerKey) return def;
    }
    return _fallback.copyWith(sectionKey: sectionKey);
  }

  /// ============================================================
  /// RESOLVE DISPLAY NAME
  /// ============================================================
  static String displayName(String sectionKey) {
    return get(sectionKey).displayName;
  }

  /// ============================================================
  /// RESOLVE ICON DATA
  /// ============================================================
  static IconData icon(String sectionKey) {
    return get(sectionKey).icon;
  }

  /// ============================================================
  /// RESOLVE DISPLAY ORDER
  /// ============================================================
  static int displayOrder(String sectionKey) {
    return get(sectionKey).displayOrder;
  }

  /// ============================================================
  /// RESOLVE LAYOUT STYLE
  /// ============================================================
  ///
  /// Returns layout style for the section.
  /// If the module count > 4 and section supports carousel,
  /// returns 'carousel'. Otherwise returns the default layout.
  /// ============================================================
  static String layoutStyle(String sectionKey, {int moduleCount = 0}) {
    final def = get(sectionKey);
    if (def.supportsCarousel && moduleCount > 4) {
      return 'carousel';
    }
    return def.layoutStyle;
  }

  /// ============================================================
  /// CHECK IF SECTION IS KNOWN
  /// ============================================================
  static bool isKnown(String sectionKey) {
    final lowerKey = sectionKey.toLowerCase().trim();
    return _definitions.any((d) => d.sectionKey == lowerKey);
  }

  /// ============================================================
  /// LIST ALL REGISTERED SECTION KEYS
  /// ============================================================
  static List<String> get knownKeys =>
      _definitions.map((d) => d.sectionKey).toSet().toList();
}

/// ============================================================
/// FALLBACK COPY-WITH EXTENSION
/// ============================================================
extension _SectionDefinitionCopy on SectionDefinition {
  SectionDefinition copyWith({String? sectionKey}) => SectionDefinition(
        sectionKey: sectionKey ?? this.sectionKey,
        displayName: displayName,
        icon: icon,
        displayOrder: displayOrder,
        layoutStyle: layoutStyle,
        maxWidgets: maxWidgets,
        supportsCarousel: supportsCarousel,
      );
}
