/// ============================================================
/// ORGANIZATION RUNTIME — DOMAIN BARREL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/domain/ = organization domain models
///
/// The Organization Runtime domain models are the single source
/// of truth for the active organization state.
///
/// Every feature reads `activeOrganizationProvider` instead of
/// reading organizationId, organizationType, country, county
/// from multiple places.
///
/// ✅ Design Principles:
///   - Pure data — no evaluation logic
///   - Immutable — always use copyWith
///   - No database, no UI, no Flutter
///   - Ready for future backend alignment
/// ============================================================
library;

export 'organization_context.dart';
export 'organization_type.dart';
