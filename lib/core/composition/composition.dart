/// ============================================================
/// COMPOSITION ENGINE — PUBLIC API
/// ============================================================
library;

// ── Domain Models ──
export 'domain/models/runtime_module.dart';
export 'domain/models/composition_metrics.dart';

// ── Engine ──
export 'engine/runtime_composition_engine.dart';
export 'engine/dependency_resolver.dart';
export 'engine/module_access_filter.dart';
export 'engine/module_to_runtime_mapper.dart';

// ── Dashboard ──
export 'dashboard/dashboard_composer.dart';

// ── Navigation ──
export 'navigation/composition_nav_builder.dart';

// ── Router (also exports bootstrapModulePageBuilders) ──
export 'router/dynamic_route_registrar.dart';

// ── Providers ──
export 'providers/composition_providers.dart';

// ── Runtime Contribution Engine ──
export 'contributions/contribution_models.dart';
export 'contributions/contribution_registry.dart';
export 'contributions/contribution_provider.dart';
export 'contributions/runtime_contribution_engine.dart';

// ── Home Composition ──
export 'home/home_contribution_composer.dart';
export 'home/home_providers.dart';

// ── Observability ──
export 'observability/contribution_observability.dart';

