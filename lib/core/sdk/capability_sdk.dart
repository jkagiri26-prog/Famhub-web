/// ============================================================
/// CAPABILITY SDK — Public facade for capability evaluation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose capability checks to feature modules
///   - Delegate to capabilityEngineProvider
///   - Never expose CapabilityEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/capabilities/application/capability_provider.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// CAPABILITY SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final caps = ref.read(famhubCapabilitySdkProvider);
///   if (caps.has(Capabilities.marketplaceListings)) { ... }
///   final level = caps.level(Capabilities.workflowExecution);
///   if (caps.canExecute(Capabilities.workflowExecution)) { ... }
/// ============================================================
@publicSdk()
class CapabilitySdk {
  final Ref _ref;

  CapabilitySdk(this._ref);

  /// Check if a specific capability is enabled
  @sdkMethod(version: '1.0.0')
  bool has(Object capability) =>
      _ref.read(hasCapabilityProvider(capability));

  /// Get the level of a specific capability (0 = disabled)
  @sdkMethod(version: '1.0.0')
  int level(Object capability) =>
      _ref.read(capabilityLevelProvider(capability));

  /// Check if a workflow or operation can be executed
  @sdkMethod(version: '1.0.0')
  bool canExecute(Object capability) =>
      _ref.read(canExecuteProvider(capability));

  /// Check if automation is available for a capability (level >= 5)
  @sdkMethod(version: '1.0.0')
  bool canAutomate(Object capability) =>
      _ref.read(canAutomateProvider(capability));

  /// Check if a widget or UI component should be rendered
  @sdkMethod(version: '1.0.0')
  bool canRender(Object capability) =>
      _ref.read(canRenderProvider(capability));

  /// Check if AI optimization is available (level >= 6)
  @Deprecated('Use AccessSdk.canUseAI() instead')
  @sdkMethod(version: '1.0.0')
  bool canUseAI(Object capability) {
    final lvl = _ref.read(capabilityLevelProvider(capability));
    return lvl >= 6;
  }

  /// Get all enabled capability IDs
  @sdkMethod(version: '1.0.0')
  List<String> enabledCapabilityIds() =>
      _ref.read(enabledCapabilityIdsProvider);

  /// Get all capability levels as a map
  @sdkMethod(version: '1.0.0')
  Map<String, int> allLevels() =>
      _ref.read(allCapabilityLevelsProvider);

  /// Check if ALL listed capabilities are enabled
  @sdkMethod(version: '1.0.0')
  bool hasAll(List<Object> capabilities) =>
      capabilities.every((c) => has(c));

  /// Check if ANY listed capability is enabled
  @sdkMethod(version: '1.0.0')
  bool hasAny(List<Object> capabilities) =>
      capabilities.any((c) => has(c));
}

/// ============================================================
/// PROVIDER: CAPABILITY SDK
/// ============================================================
@SdkProvider()
final famhubCapabilitySdkProvider = Provider<CapabilitySdk>((ref) {
  return CapabilitySdk(ref);
});

