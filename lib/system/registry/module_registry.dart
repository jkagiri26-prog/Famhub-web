// ignore: dangling_library_doc_comments
/// ============================================================
/// MODULE REGISTRY (PURE BLUEPRINT CATALOG)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// This file contains ONLY static module definitions.
///
/// ✅ Allowed:
///   - Static module definitions
///   - Declarative constants
///
/// ❌ Forbidden:
///   - Runtime query/filter logic
///   - Role-based filtering
///   - Widget/UI references
///   - Supabase/service calls
///   - Stateful logic
/// ============================================================

import 'registry_contracts.dart';

/// ============================================================
/// MODULE REGISTRY — STATIC DEFINITIONS ONLY
/// ============================================================
///
/// Central catalog of all system module blueprints.
///
/// This is a PURE DECLARATIVE registry.
/// It does NOT execute anything, filter anything,
/// or depend on any runtime state.
///
/// 🧠 USAGE:
///   - Reference by dashboard_engine for composition
///   - Reference by module_control for governance
///   - Reference by services for runtime evaluation
/// ============================================================
class ModuleRegistry {
  /// ============================================================
  /// ALL MODULE DEFINITIONS (STATIC BLUEPRINTS)
  /// ============================================================
    static const List<ModuleDefinition> definitions = [
    // ─────────────────────────────────────────────
    // Farm Management Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'farm_management',
      name: 'Farm Management',
      description: 'Manage farms, fields, crops, and livestock operations',
      version: '1.0.0',
      entryRoute: '/farm',
      iconKey: 'agriculture',
      displayOrder: 1,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Marketplace Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'marketplace',
      name: 'Marketplace',
      description: 'Buy and sell agricultural products and services',
      version: '1.0.0',
      entryRoute: '/marketplace',
      iconKey: 'store',
      displayOrder: 2,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Analytics Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'analytics',
      name: 'Analytics',
      description: 'Data analytics and insights dashboard',
      version: '1.0.0',
      entryRoute: '/analytics',
      iconKey: 'analytics',
      displayOrder: 3,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

        // ─────────────────────────────────────────────
    // Finance Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'finance',
      name: 'Finance',
      description: 'Agricultural loans, credit, and financial services',
      version: '1.0.0',
      entryRoute: '/finance',
      iconKey: 'finance',
      displayOrder: 4,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Logistics Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'logistics',
      name: 'Logistics',
      description: 'Transportation and supply chain management',
      version: '1.0.0',
      entryRoute: '/logistics',
      iconKey: 'shipping',
      displayOrder: 5,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Traceability Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'traceability',
      name: 'Traceability',
      description: 'Farm-to-table product traceability and certification',
      version: '1.0.0',
      entryRoute: '/traceability',
      iconKey: 'qr_code',
      displayOrder: 6,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Carbon Credit Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'carbon_credit',
      name: 'Carbon Credit',
      description: 'Carbon sequestration tracking and credit trading',
      version: '1.0.0',
      entryRoute: '/carbon-credit',
      iconKey: 'eco',
      displayOrder: 7,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Knowledge Link Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'knowledge_link',
      name: 'Knowledge Link',
      description: 'Agricultural knowledge base and learning resources',
      version: '1.0.0',
      entryRoute: '/knowledge',
      iconKey: 'library',
      displayOrder: 8,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Agribusiness Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'agribusiness',
      name: 'Agribusiness',
      description: 'Business management tools for agricultural enterprises',
      version: '1.0.0',
      entryRoute: '/agribusiness',
      iconKey: 'business',
      displayOrder: 9,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Opportunities Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'opportunities',
      name: 'Opportunities',
      description: 'Grants, tenders, and business opportunities',
      version: '1.0.0',
      entryRoute: '/opportunities',
      iconKey: 'opportunities',
      displayOrder: 10,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Extension Services Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'extension_services',
      name: 'Extension Services',
      description: 'Agricultural extension and advisory services',
      version: '1.0.0',
      entryRoute: '/extension',
      iconKey: 'support',
      displayOrder: 11,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // AgriConnect Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'agri_connect',
      name: 'AgriConnect',
      description: 'Farmer networking and community features',
      version: '1.0.0',
      entryRoute: '/connect',
      iconKey: 'community',
      displayOrder: 12,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Agri Tech Lab Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'agri_tech_lab',
      name: 'AgriTech Lab',
      description: 'Innovation lab for agricultural technology experiments',
      version: '1.0.0',
      entryRoute: '/tech-lab',
      iconKey: 'science',
      displayOrder: 13,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Referral Hub Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'referral_hub',
      name: 'Referral Hub',
      description: 'Referral program and reward tracking',
      version: '1.0.0',
      entryRoute: '/referrals',
      iconKey: 'referral',
      displayOrder: 14,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Profile Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'profile',
      name: 'Profile',
      description: 'User profile and account management',
      version: '1.0.0',
      entryRoute: '/profile',
      iconKey: 'profile',
      displayOrder: 15,
      isEnabledDefault: true,
      isVisibleDefault: true,
      maintenanceModeDefault: false,
    ),

    // ─────────────────────────────────────────────
    // Admin Console Module
    // ─────────────────────────────────────────────
    ModuleDefinition(
      moduleId: 'admin_console',
      name: 'Admin Console',
      description: 'System administration and configuration',
      version: '1.0.0',
      entryRoute: '/admin',
      iconKey: 'admin',
      displayOrder: 16,
      isEnabledDefault: false,
      isVisibleDefault: false,
      maintenanceModeDefault: false,
    ),
  ];

  /// ============================================================
  /// LOOKUP HELPERS (PURE DECLARATIVE QUERIES ONLY)
  /// ============================================================
  ///
  /// These are pure, deterministic lookups on static data only.
  /// NO runtime state, NO services, NO async operations.
  /// ============================================================

  /// Find a module definition by its ID.
  /// Pure lookup — no I/O, no exceptions thrown.
  static ModuleDefinition? byId(String moduleId) {
    for (final def in definitions) {
      if (def.moduleId == moduleId) return def;
    }
    return null;
  }

  /// Find a module definition by route path.
  /// Pure lookup — no I/O, no exceptions thrown.
  static ModuleDefinition? byRoute(String route) {
    for (final def in definitions) {
      if (def.entryRoute == route) return def;
    }
    return null;
  }
}