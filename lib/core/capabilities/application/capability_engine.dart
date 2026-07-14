/// ============================================================
/// CAPABILITY ENGINE — PURE OPERATIONAL EVALUATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/application/ = capability application layer
///
/// The Capability Engine is the SINGLE entry point for all
/// operational capability checks in the application. Every
/// module, workflow, service, renderer, and automation engine
/// MUST use this engine instead of organization-type checks
/// or subscription tier checks.
///
/// ✅ Responsibilities:
///   - Evaluate capability availability
///   - Evaluate capability level
///   - Expose helper methods: canExecute, canRender, canAutomate
///   - Cache resolved capabilities for performance
///
/// ❌ Does NOT:
///   - Perform UI rendering
///   - Perform database writes
///   - Import Flutter UI
///   - Check organization types or subscription tiers
///   - Replace RuntimeFeatureFlags (they serve different concerns)
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Instead of:
///     if (enterprise) → show X
///     if (aggregator) → show Y
///     if (cooperative) → show Z
///
///   Always use:
///     engine.hasCapability(Capabilities.workflowExecution)
///     engine.getCapabilityLevel(Capabilities.inventoryStock)
///
///   Every behavioral difference originates from the Capability Framework.
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/capabilities/domain/capability_profile.dart';
import 'package:famhub_app/core/capabilities/domain/capability_level.dart';
import 'package:famhub_app/core/capabilities/registry/capability_registry.dart';

/// ============================================================
/// CAPABILITY ENGINE
/// ============================================================
///
/// Pure evaluation engine. All capability decisions flow
/// through this engine. It is stateless beyond its profile.
/// ============================================================
class CapabilityEngine {
  /// The organization's capability profile
  final CapabilityProfile profile;

  /// Internal cache for fast lookups
  final Map<String, bool> _enabledCache = {};
  final Map<String, int> _levelCache = {};

  CapabilityEngine({required this.profile});

  /// ============================================================
  /// FACTORY: CREATE FROM PROFILE
  /// ============================================================
  factory CapabilityEngine.fromProfile(CapabilityProfile profile) =>
      CapabilityEngine(profile: profile);

  /// ============================================================
  /// FACTORY: CREATE WITH DEFAULTS (FOR TESTING)
  /// ============================================================
  factory CapabilityEngine.withDefaults({
    required String organizationId,
    bool enableAll = false,
  }) =>
      CapabilityEngine(
        profile: enableAll
            ? CapabilityProfileFactory.full(organizationId)
            : CapabilityProfileFactory.empty(organizationId),
      );

  /// ============================================================
  /// HAS CAPABILITY
  /// ============================================================
  ///
  /// Returns true if the capability is enabled (level > 0).
  /// Accepts either a Capability object or a string ID.
  /// ============================================================
  bool hasCapability(Object capability) {
    final id = _resolveId(capability);

    // Check cache
    if (_enabledCache.containsKey(id)) {
      return _enabledCache[id]!;
    }

    final result = _evaluateEnabled(id);
    _enabledCache[id] = result;
    return result;
  }

  /// ============================================================
  /// GET CAPABILITY LEVEL
  /// ============================================================
  ///
  /// Returns the assigned level for a capability.
  /// Returns 0 (disabled) if not found in profile.
  /// ============================================================
  int getCapabilityLevel(Object capability) {
    final id = _resolveId(capability);

    // Check cache
    if (_levelCache.containsKey(id)) {
      return _levelCache[id]!;
    }

    final level = profile.levelFor(id);
    _levelCache[id] = level;
    return level;
  }

  /// ============================================================
  /// GET CAPABILITY LEVEL DETAILS
  /// ============================================================
  ///
  /// Returns the CapabilityLevel object for the current level.
  /// Returns null if the capability is not registered.
  /// ============================================================
  CapabilityLevel? getCapabilityLevelDetails(Object capability) {
    final id = _resolveId(capability);
    final level = getCapabilityLevel(id);
    final registration = CapabilityRegistry.get(id);
    return registration?.levelFor(level);
  }

  /// ============================================================
  /// CAN EXECUTE
  /// ============================================================
  ///
  /// Checks if a workflow or operation can be executed.
  /// This is a semantic helper over hasCapability.
  /// ============================================================
  bool canExecute(Object capability) => hasCapability(capability);

  /// ============================================================
  /// CAN RENDER
  /// ============================================================
  ///
  /// Checks if a widget or UI component should be rendered.
  /// This is a semantic helper over hasCapability.
  /// ============================================================
  bool canRender(Object capability) => hasCapability(capability);

  /// ============================================================
  /// CAN AUTOMATE
  /// ============================================================
  ///
  /// Checks if automation is available for a capability.
  /// By convention, automation requires level >= 5.
  /// ============================================================
  bool canAutomate(Object capability) {
    final id = _resolveId(capability);
    return getCapabilityLevel(id) >= 5;
  }

  /// ============================================================
  /// CAN USE AI
  /// ============================================================
  ///
  /// Checks if AI optimization is available for a capability.
  /// By convention, AI requires level >= 6.
  /// ============================================================
  bool canUseAI(Object capability) {
    final id = _resolveId(capability);
    return getCapabilityLevel(id) >= 6;
  }

  /// ============================================================
  /// HAS ALL CAPABILITIES
  /// ============================================================
  ///
  /// Returns true only if ALL listed capabilities are enabled.
  /// ============================================================
  bool hasAllCapabilities(List<Object> capabilities) =>
      capabilities.every(hasCapability);

  /// ============================================================
  /// HAS ANY CAPABILITY
  /// ============================================================
  ///
  /// Returns true if AT LEAST ONE listed capability is enabled.
  /// ============================================================
  bool hasAnyCapability(List<Object> capabilities) =>
      capabilities.any(hasCapability);

  /// ============================================================
  /// GET ENABLED CAPABILITY IDs
  /// ============================================================
  ///
  /// Returns the list of all enabled capability IDs from the profile.
  /// ============================================================
  List<String> get enabledCapabilityIds => profile.enabledCapabilityIds;

  /// ============================================================
  /// GET ALL LEVELS
  /// ============================================================
  ///
  /// Returns the full capability → level map.
  /// ============================================================
  Map<String, int> get allLevels =>
      Map<String, int>.from(profile.capabilities);

  /// ============================================================
  /// INVALIDATE CACHE
  /// ============================================================
  ///
  /// Call when the profile changes to force re-evaluation.
  /// ============================================================
  void invalidateCache() {
    _enabledCache.clear();
    _levelCache.clear();
  }

  /// ============================================================
  /// UPDATE PROFILE
  /// ============================================================
  ///
  /// Replace the profile and invalidate cache.
  /// ============================================================
  void updateProfile(CapabilityProfile newProfile) {
    // profile is final — use copy
    invalidateCache();
    // Note: profile is final; creation of new engine required.
    // This method is kept for API consistency but the immutability
    // pattern means callers should create a new engine.
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  bool _evaluateEnabled(String capabilityId) {
    // Check if the capability is registered
    if (!CapabilityRegistry.hasCapability(capabilityId)) {
      return false;
    }

    // Check the profile for this capability
    return profile.hasCapability(capabilityId);
  }

  String _resolveId(Object capability) {
    if (capability is Capability) {
      return capability.id;
    }
    if (capability is String) {
      return capability;
    }
    throw ArgumentError(
      'Capability must be a Capability object or a String ID. '
      'Got: ${capability.runtimeType}',
    );
  }
}
