/// ============================================================
/// CAPABILITY FRAMEWORK — BARREL EXPORT
/// ============================================================
///
/// Single import point for all capability framework components.
///
/// Usage:
///   import 'package:famhub_app/core/capabilities/capabilities.dart';
///
/// Then:
///   ref.watch(hasCapabilityProvider(Capabilities.inventoryStock))
///   ref.watch(capabilityEngineProvider)?.hasCapability(...)
///   CapabilityRegistry.get('marketplace.listings')
/// ============================================================
library;

// ── Domain ──
export 'domain/capability.dart';
export 'domain/capability_level.dart';
export 'domain/capability_profile.dart';

// ── Registry ──
export 'registry/capability_registry.dart';

// ── Application ──
export 'application/capability_engine.dart';
export 'application/capability_provider.dart';
export 'application/capability_profile_provider.dart';

// ── Infrastructure ──
export 'infrastructure/organization_capability_repository.dart';

// ── Composition Bridge ──
export 'composition/capability_composition_bridge.dart';

// ── Bootstrap ──
export 'bootstrap/capability_bootstrap.dart';
