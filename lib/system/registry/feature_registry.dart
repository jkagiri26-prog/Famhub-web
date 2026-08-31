// ignore: dangling_library_doc_comments
/// ============================================================
/// FEATURE REGISTRY (PURE BLUEPRINT CATALOG)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// Static feature definitions for all system modules.
/// Declares what capabilities each module offers.
///
/// ✅ Allowed:
///   - Static feature definitions
///   - Default state declarations
///
/// ❌ Forbidden:
///   - Runtime feature evaluation logic
///   - Provider/UI imports
///   - Async/Supabase calls
///   - User-specific logic
/// ============================================================

import 'registry_contracts.dart';

/// ============================================================
/// FEATURE REGISTRY — STATIC CAPABILITY DECLARATIONS
/// ============================================================
///
/// Central catalog of all feature definitions across modules.
/// These are PURE DECLARATIONS — no runtime evaluation.
///
/// Runtime evaluation of features belongs in:
///   core/services/ or features/*/application/
/// ============================================================
class FeatureRegistry {
  /// ============================================================
  /// ALL FEATURE DEFINITIONS (STATIC BLUEPRINTS)
  /// ============================================================
  static const List<FeatureDefinition> definitions = [
    // ── Farm Management Features ─────────────────
    FeatureDefinition(
      featureKey: 'farm_dashboard',
      moduleId: 'farm_management',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Farm overview dashboard',
    ),
    FeatureDefinition(
      featureKey: 'farm_crop_management',
      moduleId: 'farm_management',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Crop planning and management',
    ),
    FeatureDefinition(
      featureKey: 'farm_livestock_management',
      moduleId: 'farm_management',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Livestock tracking and management',
    ),
    FeatureDefinition(
      featureKey: 'farm_analytics',
      moduleId: 'farm_management',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'Advanced farm analytics and insights',
    ),

    // ── Marketplace Features ────────────────────
    FeatureDefinition(
      featureKey: 'marketplace_browse',
      moduleId: 'marketplace',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Browse marketplace listings',
    ),
    FeatureDefinition(
      featureKey: 'marketplace_list',
      moduleId: 'marketplace',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Create and manage listings',
    ),
    FeatureDefinition(
      featureKey: 'marketplace_ai_seller',
      moduleId: 'marketplace',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'AI-powered seller assistant',
    ),

    // ── Analytics Features ──────────────────────
    FeatureDefinition(
      featureKey: 'analytics_basic',
      moduleId: 'analytics',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Basic analytics dashboard',
    ),
    FeatureDefinition(
      featureKey: 'analytics_advanced',
      moduleId: 'analytics',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'Advanced analytics and reporting',
    ),
    FeatureDefinition(
      featureKey: 'analytics_predictive',
      moduleId: 'analytics',
      defaultEnabled: false,
      requiredTier: 'enterprise',
      description: 'Predictive analytics and forecasting',
    ),

    // ── Finance Features ─────────────────────────
    FeatureDefinition(
      featureKey: 'finance_browse',
      moduleId: 'finance',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Browse loan offers and partners',
    ),
    FeatureDefinition(
      featureKey: 'finance_apply',
      moduleId: 'finance',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Apply for financing',
    ),
    FeatureDefinition(
      featureKey: 'finance_credit_health',
      moduleId: 'finance',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'Credit health monitoring and insights',
    ),

    // ── Logistics Features ──────────────────────
    FeatureDefinition(
      featureKey: 'logistics_track',
      moduleId: 'logistics',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Track shipments',
    ),
    FeatureDefinition(
      featureKey: 'logistics_book',
      moduleId: 'logistics',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Book transportation services',
    ),

    // ── Traceability Features ───────────────────
    FeatureDefinition(
      featureKey: 'traceability_view',
      moduleId: 'traceability',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'View product traceability information',
    ),
    FeatureDefinition(
      featureKey: 'traceability_certify',
      moduleId: 'traceability',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'Create and manage certifications',
    ),

    // ── Carbon Credit Features ──────────────────
    FeatureDefinition(
      featureKey: 'carbon_calculator',
      moduleId: 'carbon_credit',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Carbon footprint calculator',
    ),
    FeatureDefinition(
      featureKey: 'carbon_trade',
      moduleId: 'carbon_credit',
      defaultEnabled: false,
      requiredTier: 'premium',
      description: 'Carbon credit trading platform',
    ),

    // ── Knowledge Link Features ─────────────────
    FeatureDefinition(
      featureKey: 'knowledge_browse',
      moduleId: 'knowledge',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'Browse knowledge articles and guides',
    ),
    FeatureDefinition(
      featureKey: 'knowledge_create',
      moduleId: 'knowledge',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Create and publish knowledge content',
    ),

    // ── Referral Hub Features ───────────────────
    FeatureDefinition(
      featureKey: 'referral_view',
      moduleId: 'referral_hub',
      defaultEnabled: true,
      requiredTier: 'free',
      description: 'View referral program information',
    ),
    FeatureDefinition(
      featureKey: 'referral_earnings',
      moduleId: 'referral_hub',
      defaultEnabled: true,
      requiredTier: 'basic',
      description: 'Track referral earnings and milestones',
    ),
  ];

  /// ============================================================
  /// PURE LOOKUP HELPERS
  /// ============================================================

  /// Get all features for a given module.
  static List<FeatureDefinition> forModule(String moduleId) {
    final result = <FeatureDefinition>[];
    for (final def in definitions) {
      if (def.moduleId == moduleId) {
        result.add(def);
      }
    }
    return result;
  }

  /// Find a feature by its key.
  static FeatureDefinition? byKey(String featureKey) {
    for (final def in definitions) {
      if (def.featureKey == featureKey) return def;
    }
    return null;
  }
}
