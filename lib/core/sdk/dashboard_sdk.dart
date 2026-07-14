/// ============================================================
/// DASHBOARD SDK — Public facade for dashboard composition
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose dashboard composition state to feature modules
///   - Delegate to descriptor providers and composition engine
///   - Never expose DashboardCompositionEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain rendering logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// DASHBOARD SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final dash = ref.read(famhubDashboardSdkProvider);
///   final widgets = dash.widgets();
///   final actions = dash.quickActions();
///   await dash.refresh();
/// ============================================================
@publicSdk()
class DashboardSdk {
  final Ref _ref;

  DashboardSdk(this._ref);

  /// Trigger a refresh of dashboard composition
  @SdkMethod(version: '1.0.0')
  Future<void> refresh() async {
    _ref.invalidate(dashboardWidgetDescriptorsProvider);
    _ref.invalidate(homeWidgetDescriptorsProvider);
    _ref.invalidate(quickActionDescriptorsProvider);
    _ref.invalidate(dashboardWidgetsBySectionProvider);
  }

  /// Get all dashboard widget descriptors
  @SdkMethod(version: '1.0.0')
  Future<List<DashboardWidgetDescriptor>> widgets() =>
      _ref.read(dashboardWidgetDescriptorsProvider.future);

  /// Get all quick action descriptors
  @SdkMethod(version: '1.0.0')
  Future<List<QuickActionDescriptor>> quickActions() =>
      _ref.read(quickActionDescriptorsProvider.future);

  /// Get all dashboard modules (widget descriptors)
  @SdkMethod(version: '1.0.0')
  Future<List<DashboardWidgetDescriptor>> dashboardModules() =>
      _ref.read(dashboardWidgetDescriptorsProvider.future);

  /// Get visible cards (dashboard widgets by section)
  @SdkMethod(version: '1.0.0')
  Future<Map<String, List<DashboardWidgetDescriptor>>> visibleCards() =>
      _ref.read(dashboardWidgetsBySectionProvider.future);

  /// Get home widget descriptors
  @SdkMethod(version: '1.0.0')
  Future<List<HomeWidgetDescriptor>> homeWidgets() =>
      _ref.read(homeWidgetDescriptorsProvider.future);

  /// Get home widgets organized by type
  @SdkMethod(version: '1.0.0')
  Future<Map<String, List<HomeWidgetDescriptor>>> homeWidgetsByType() =>
      _ref.read(homeWidgetsByTypeProvider.future);

  /// Get all enabled runtime modules
  @SdkMethod(version: '1.0.0')
  Future<List<RuntimeModule>> enabledModules() =>
      _ref.read(enabledRuntimeModulesProvider.future);
}

/// ============================================================
/// PROVIDER: DASHBOARD SDK
/// ============================================================
@SdkProvider()
final famhubDashboardSdkProvider = Provider<DashboardSdk>((ref) {
  return DashboardSdk(ref);
});
