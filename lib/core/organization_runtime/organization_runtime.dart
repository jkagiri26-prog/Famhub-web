/// ============================================================
/// ORGANIZATION RUNTIME — BARREL EXPORT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/ = organization runtime root
///
/// The Organization Runtime is the SINGLE source of truth for
/// the active organization. Every feature reads the
/// `activeOrganizationProvider` instead of reading
/// organizationId, organizationType, countryId, countyId
/// from multiple places.
///
/// ✅ ARCHITECTURE:
///   Active Organization Provider
///        ↓
///   Organization Runtime Bridge
///        ↓
///   ┌──────────────┬──────────────┬──────────────┐
///   ↓              ↓              ↓              ↓
///   Capability   Policy        Access       Runtime
///   Engine       Engine        Engine       Decision
///                                            Engine
///        ↓              ↓              ↓              ↓
///   └──────────────┴──────────────┴──────────────┘
///        ↓
///   Navigation · Dashboard · Quick Actions · Widgets
///
/// ✅ DESIGN PRINCIPLES:
///   - No organization logic inside Entity Context
///   - No organization logic inside Capability Engine
///   - Dedicated runtime with single responsibility
///   - Immutable state model (OrganizationContext)
///   - Every feature reads activeOrganizationProvider
///   - No engine loads organizations independently
///   - Runtime refresh pipeline on organization switch
///   - Ready for future backend alignment
///
/// ✅ FUTURE BACKEND ALIGNMENT:
///   The backend will eventually be the source of:
///   - organization membership
///   - active organization
///   - organization hierarchy
///   - organization verification
///   - subscriptions
///   - capability profile
///   - policy profile
///
///   The frontend should only consume the runtime,
///   never backend tables directly.
/// ============================================================
library;

// ── Domain Models ──
export 'domain/organization_runtime.dart';
export 'domain/organization_context.dart';
export 'domain/organization_type.dart';

// ── Application Layer ──
export 'application/organization_runtime_engine.dart';
export 'application/organization_runtime_provider.dart';
export 'application/active_organization_provider.dart';

// ── Infrastructure Layer ──
export 'infrastructure/organization_runtime_repository.dart';

// ── Composition Layer ──
export 'composition/organization_runtime_bridge.dart';
