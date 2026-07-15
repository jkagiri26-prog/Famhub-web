// ignore: dangling_library_doc_comments
/// ============================================================
/// ACCESS REGISTRY (PURE DECLARATIVE RULES)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// Static access constraint declarations for roles, tiers,
/// and permission mappings.
///
/// ✅ Allowed:
///   - Static role constraint declarations
///   - Static tier requirement declarations
///   - Static permission mapping definitions
///
/// ❌ Forbidden:
///   - Runtime access evaluation
///   - User-specific logic
///   - Session/auth logic
///   - Supabase/service calls
///   - Provider/UI imports
/// ============================================================

import 'registry_contracts.dart';

/// ============================================================
/// ACCESS REGISTRY — STATIC ACCESS RULE DECLARATIONS
/// ============================================================
///
/// This registry defines WHAT the access rules ARE,
/// not how they are EVALUATED.
///
/// 🧠 SEPARATION OF CONCERNS:
///   - system/registry/access_registry.dart = WHAT (declarative rules)
///   - core/services/permission_service.dart = HOW (runtime evaluation)
///   - core/access/ = POLICY DECISION ENGINE (runtime evaluation)
/// ============================================================
class AccessRegistry {
  /// ============================================================
  /// ALL ACCESS RULES (STATIC DECLARATIONS)
  /// ============================================================
  static const List<AccessRule> rules = [
    // ── Admin Module ────────────────────────────
    AccessRule(
      resourceKey: 'admin_console',
      allowedRoles: ['admin', 'super_admin'],
      requiredTier: 'enterprise',
      permissionMappings: {
        'view': 'admin.view',
        'configure': 'admin.configure',
        'manage_users': 'admin.users.manage',
      },
    ),

    // ── Farm Management ─────────────────────────
    AccessRule(
      resourceKey: 'farm_management',
      allowedRoles: ['farmer', 'admin', 'extension_officer'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'farm.view',
        'create': 'farm.create',
        'edit': 'farm.edit',
        'delete': 'farm.delete',
      },
    ),

    // ── Marketplace ─────────────────────────────
    AccessRule(
      resourceKey: 'marketplace',
      allowedRoles: ['farmer', 'buyer', 'admin'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'marketplace.view',
        'list': 'marketplace.list',
        'purchase': 'marketplace.purchase',
      },
    ),

    // ── Analytics ───────────────────────────────
    AccessRule(
      resourceKey: 'analytics',
      allowedRoles: ['farmer', 'admin', 'agronomist'],
      requiredTier: 'free',
      permissionMappings: {
        'view_basic': 'analytics.basic.view',
        'view_advanced': 'analytics.advanced.view',
        'export': 'analytics.export',
      },
    ),

    // ── Finance ──────────────────────────────────
    AccessRule(
      resourceKey: 'finance',
      allowedRoles: ['farmer', 'admin', 'financial_advisor'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'finance.view',
        'apply': 'finance.apply',
        'manage': 'finance.manage',
      },
    ),

    // ── Logistics ───────────────────────────────
    AccessRule(
      resourceKey: 'logistics',
      allowedRoles: ['farmer', 'buyer', 'transporter', 'admin'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'logistics.view',
        'book': 'logistics.book',
        'track': 'logistics.track',
      },
    ),

    // ── Traceability ────────────────────────────
    AccessRule(
      resourceKey: 'traceability',
      allowedRoles: ['farmer', 'buyer', 'admin', 'certifier'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'traceability.view',
        'certify': 'traceability.certify',
        'verify': 'traceability.verify',
      },
    ),

    // ── Carbon Credit ───────────────────────────
    AccessRule(
      resourceKey: 'carbon_credit',
      allowedRoles: ['farmer', 'admin', 'carbon_auditor'],
      requiredTier: 'free',
      permissionMappings: {
        'calculate': 'carbon.calculate',
        'trade': 'carbon.trade',
        'audit': 'carbon.audit',
      },
    ),

    // ── Knowledge Link ──────────────────────────
    AccessRule(
      resourceKey: 'knowledge_link',
      allowedRoles: ['farmer', 'admin', 'extension_officer', 'agronomist'],
      requiredTier: 'free',
      permissionMappings: {
        'read': 'knowledge.read',
        'create': 'knowledge.create',
        'publish': 'knowledge.publish',
        'moderate': 'knowledge.moderate',
      },
    ),

    // ── Profile ─────────────────────────────────
    AccessRule(
      resourceKey: 'profile',
      allowedRoles: ['*'], // all authenticated users
      requiredTier: 'free',
      permissionMappings: {
        'view_own': 'profile.own.view',
        'edit_own': 'profile.own.edit',
        'view_admin': 'profile.admin.view',
      },
    ),

    // ── Referral Hub ────────────────────────────
    AccessRule(
      resourceKey: 'referral_hub',
      allowedRoles: ['farmer', 'buyer', 'admin'],
      requiredTier: 'free',
      permissionMappings: {
        'view': 'referral.view',
        'earn': 'referral.earn',
        'withdraw': 'referral.withdraw',
      },
    ),
  ];

  /// ============================================================
  /// PURE LOOKUP HELPERS
  /// ============================================================

  /// Get access rules for a specific resource.
  static AccessRule? forResource(String resourceKey) {
    for (final rule in rules) {
      if (rule.resourceKey == resourceKey) return rule;
    }
    return null;
  }

  /// Get all rules applicable to a specific role.
  static List<AccessRule> forRole(String role) {
    final result = <AccessRule>[];
    for (final rule in rules) {
      if (rule.allowedRoles.contains(role) ||
          rule.allowedRoles.contains('*')) {
        result.add(rule);
      }
    }
    return result;
  }
}
