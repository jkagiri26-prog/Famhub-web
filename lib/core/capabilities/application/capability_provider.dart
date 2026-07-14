/// ============================================================
/// CAPABILITY PROVIDERS — RUNTIME BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/application/ = capability application layer
///
/// These Riverpod providers bridge the Capability Engine with the
/// rest of the application. They are the runtime connection between
/// the organization profile and every rendering decision.
///
/// ✅ Responsibilities:
///   - Expose CapabilityEngine through Riverpod
///   - Auto-invalidate on organization/context changes
///   - Provide convenient capability query providers
///
/// ❌ Does NOT:
///   - Perform UI rendering
///   - Evaluate subscription tiers
///   - Check organization types
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/capabilities/domain/capability_profile.dart';
import 'package:famhub_app/core/capabilities/application/capability_engine.dart';
import 'package:famhub_app/core/capabilities/application/capability_profile_provider.dart';

/// ============================================================
/// PROVIDER: CAPABILITY ENGINE
/// ============================================================
///
/// The main capability engine provider. Rebuilds whenever the
/// capability profile changes.
///
/// All modules, workflows, and components use this provider
/// to check operational permissions.
/// ============================================================
final capabilityEngineProvider = Provider<CapabilityEngine?>((ref) {
  final profile = ref.watch(capabilityProfileProvider);
  if (profile == null) return null;
  return CapabilityEngine.fromProfile(profile);
});

/// ============================================================
/// PROVIDER: SINGLE CAPABILITY CHECK
/// ============================================================
///
/// Family provider to check if a specific capability is enabled.
/// Usage:
///   final canList = ref.watch(hasCapabilityProvider(Capabilities.marketplaceListings));
///   final canExecute = ref.watch(hasCapabilityProvider('workflow.execution'));
/// ============================================================
final hasCapabilityProvider = Provider.family<bool, Object>((ref, capability) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return false;
  return engine.hasCapability(capability);
});

/// ============================================================
/// PROVIDER: CAPABILITY LEVEL
/// ============================================================
///
/// Family provider to get the level of a specific capability.
/// Usage:
///   final level = ref.watch(capabilityLevelProvider(Capabilities.workflowExecution));
///   if (level >= 3) { /* show financials */ }
/// ============================================================
final capabilityLevelProvider = Provider.family<int, Object>((ref, capability) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return 0;
  return engine.getCapabilityLevel(capability);
});

/// ============================================================
/// PROVIDER: CAN EXECUTE
/// ============================================================
///
/// Semantic family provider for execution checks.
/// ============================================================
final canExecuteProvider = Provider.family<bool, Object>((ref, capability) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return false;
  return engine.canExecute(capability);
});

/// ============================================================
/// PROVIDER: CAN RENDER
/// ============================================================
///
/// Semantic family provider for rendering checks.
/// ============================================================
final canRenderProvider = Provider.family<bool, Object>((ref, capability) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return false;
  return engine.canRender(capability);
});

/// ============================================================
/// PROVIDER: CAN AUTOMATE
/// ============================================================
///
/// Semantic family provider for automation checks.
/// ============================================================
final canAutomateProvider = Provider.family<bool, Object>((ref, capability) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return false;
  return engine.canAutomate(capability);
});

/// ============================================================
/// PROVIDER: ENABLED CAPABILITY IDS
/// ============================================================
///
/// Returns the list of all currently enabled capability IDs.
/// ============================================================
final enabledCapabilityIdsProvider = Provider<List<String>>((ref) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return [];
  return engine.enabledCapabilityIds;
});

/// ============================================================
/// PROVIDER: ALL CAPABILITY LEVELS
/// ============================================================
///
/// Returns the full map of capability ID → level.
/// ============================================================
final allCapabilityLevelsProvider = Provider<Map<String, int>>((ref) {
  final engine = ref.watch(capabilityEngineProvider);
  if (engine == null) return {};
  return engine.allLevels;
});
