/// ============================================================
/// ORGANIZATION TYPE — RUNTIME ENUM
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/domain/ = organization domain models
///
/// Types of organizations supported by the system.
/// These represent the primary operational classifications.
///
/// ✅ Usage:
///   Instead of string-based type checks, use this enum.
///   Helps avoid inconsistency in type comparison.
///
/// ✅ Future Backend Alignment:
///   This enum mirrors the backend `organization_types` reference table.
/// ============================================================
library;

/// ============================================================
/// ORGANIZATION TYPE
/// ============================================================
///
/// Classifies the organization's role in the value chain.
/// Each type maps to specific capabilities and policies.
/// ============================================================
enum OrganizationType {
  /// Unknown or unset
  unknown,

  /// Individual smallholder farmer
  farmer,

  /// Farming cooperative or farmer group
  cooperative,

  /// Aggregator / middleman / trader
  aggregator,

  /// Export company
  exporter,

  /// Food processor or manufacturer
  processor,

  /// County government office
  countyOffice,

  /// Full enterprise / commercial operation
  enterprise,

  /// Regulatory body or government agency
  government,

  /// Non-governmental organization
  ngo,

  /// Transport / logistics company
  logistics,

  /// Financial institution / bank
  financial,

  /// Training / extension service provider
  trainer,
}
