/// ============================================================
/// CAPABILITY BOOTSTRAP — INITIALIZATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/bootstrap/ = capability initialization
///
/// Initializes the Capability Framework during app startup.
/// Must be called before any capability queries are made.
///
/// ✅ Responsibilities:
///   - Register all default capabilities in the registry
///   - Register module capability extensions
///
/// ❌ Does NOT:
///   - Fetch backend data
///   - Render UI
///   - Import providers
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/capabilities/registry/capability_registry.dart';
import 'package:famhub_app/core/capabilities/composition/capability_composition_bridge.dart';

/// ============================================================
/// BOOTSTRAP CAPABILITY FRAMEWORK
/// ============================================================
///
/// Call this once during app initialization, after the
/// module descriptor registrations.
///
/// Usage (in main.dart or startup coordinator):
///   await bootstrapCapabilities();
/// ============================================================
Future<void> bootstrapCapabilities() async {
  // ── 1. Register all default capability definitions ──
  CapabilityRegistry.registerDefaults();

  // ── 2. Register module capability requirements ──
  _registerModuleCapabilities();

  // Log completion
  // ignore: avoid_print
  print('[CAPABILITIES] Bootstrap complete — '
      '${CapabilityRegistry.registeredCapabilityIds.length} capabilities registered');
}

/// ============================================================
/// REGISTER MODULE CAPABILITY REQUIREMENTS
/// ============================================================
///
/// Each module declares what capabilities its features depend on.
/// This is how the framework knows which widgets to hide when
/// a capability is unavailable.
///
/// 🚨 IMPORTANT:
///   These registrations define operational permissions.
///   Never hide an entire module when only one feature is affected.
///   Only hide or disable the specific affected feature.
/// ============================================================
void _registerModuleCapabilities() {
  // ── Marketplace Module ──
  registerModuleCapabilities(
    'marketplace',
    requiredCapabilities: [Capabilities.marketplaceListings.id],
    widgetCapabilities: {
      'inventory_section': [Capabilities.inventoryStock.id],
      'orders_section': [Capabilities.marketplaceOrders.id],
      'finance_summary': [Capabilities.financeRecording.id],
    },
  );

  // ── Farm Management Module ──
  registerModuleCapabilities(
    'farm_management',
    widgetCapabilities: {
      'activity_workflow': [Capabilities.workflowExecution.id],
      'inventory_tab': [Capabilities.inventoryStock.id],
      'finance_tab': [Capabilities.financeRecording.id],
      'kpi_tab': [Capabilities.analyticsBasic.id],
      'traceability_tab': [Capabilities.traceabilityBasic.id],
      'staff_tab': [Capabilities.staffManagement.id],
      'spatial_map': [Capabilities.spatialView.id],
      'spatial_capture': [Capabilities.spatialCapture.id],
      'spatial_boundary_edit': [Capabilities.spatialEdit.id],
      'overlap_detection': [Capabilities.spatialAnalytics.id],
    },
  );

  // ── Carbon Credit Module ──
  registerModuleCapabilities(
    'carbon_credit',
    widgetCapabilities: {
      'carbon_map': [Capabilities.carbonSpatial.id, Capabilities.spatialView.id],
      'carbon_boundary_capture': [Capabilities.carbonSpatial.id, Capabilities.spatialCapture.id],
      'carbon_overlap_analysis': [Capabilities.carbonSpatial.id, Capabilities.spatialAnalytics.id],
    },
  );

  // ── Analytics Module ──
  registerModuleCapabilities(
    'analytics',
    widgetCapabilities: {
      'basic_dashboard': [Capabilities.analyticsBasic.id],
      'advanced_reports': [Capabilities.analyticsAdvanced.id],
    },
  );

  // ── Finance Module ──
  registerModuleCapabilities(
    'finance',
    widgetCapabilities: {
      'transaction_recording': [Capabilities.financeRecording.id],
      'invoicing': [Capabilities.financeInvoicing.id],
    },
  );

  // ── Logistics Module ──
  registerModuleCapabilities(
    'logistics',
    widgetCapabilities: {
      'dispatch_management': [Capabilities.logisticsDispatch.id],
      'shipment_tracking': [Capabilities.logisticsTracking.id],
    },
  );

  // ── Traceability Module ──
  registerModuleCapabilities(
    'traceability',
    widgetCapabilities: {
      'basic_traceability': [Capabilities.traceabilityBasic.id],
      'export_records': [Capabilities.traceabilityExport.id],
      'spatial_traceability_map': [Capabilities.traceabilitySpatial.id, Capabilities.spatialView.id],
    },
  );

  // ── Inventory Module ──
  registerModuleCapabilities(
    'inventory',
    widgetCapabilities: {
      'stock_management': [Capabilities.inventoryStock.id],
      'warehouse_management': [Capabilities.inventoryWarehouse.id],
    },
  );

  // ── Cold Chain Module ──
  registerModuleCapabilities(
    'coldchain',
    widgetCapabilities: {
      'monitoring': [Capabilities.coldchainMonitoring.id],
    },
  );

  // ── AI Assistant Module ──
  registerModuleCapabilities(
    'ai_assistant',
    widgetCapabilities: {
      'recommendations': [Capabilities.aiRecommendations.id],
    },
  );

  // ── Staff Module ──
  registerModuleCapabilities(
    'staff',
    widgetCapabilities: {
      'management': [Capabilities.staffManagement.id],
    },
  );
}
