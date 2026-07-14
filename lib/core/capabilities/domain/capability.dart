/// ============================================================
/// CAPABILITY — OPERATIONAL ABILITY CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/domain/ = capability domain models
///
/// A Capability represents an operational ability that an
/// organization is permitted to execute. Capabilities are
/// NOT subscriptions, NOT feature flags, NOT user roles.
///
/// Capabilities are permanent system contracts. Once defined,
/// they become part of the framework and should not be changed.
///
/// ✅ Responsibilities:
///   - Define a unique capability identifier
///   - Own the capability's level definitions
///   - Pure declaration — no business logic
///
/// ❌ Does NOT:
///   - Evaluate access
///   - Check subscription tiers
///   - Reference organization types
///   - Import UI
/// ============================================================
library;

/// ============================================================
/// CAPABILITY IDENTIFIER
/// ============================================================
///
/// Every capability is identified by a unique dot-separated string.
/// The format follows: <domain>.<operation>
///
/// Examples:
///   marketplace.listings
///   workflow.execution
///   inventory.stock
///   finance.recording
///   traceability.basic
/// ============================================================
class Capability {
  /// Unique dot-separated identifier
  final String id;

  /// Human-readable name
  final String name;

  /// Description of what this capability enables
  final String description;

  /// Domain grouping (e.g., 'marketplace', 'inventory', 'finance')
  final String domain;

  const Capability({
    required this.id,
    required this.name,
    required this.description,
    required this.domain,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capability &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Capability($id)';
}

/// ============================================================
/// CAPABILITY CONSTANTS
/// ============================================================
///
/// All known capabilities are defined here as static constants.
/// Every system capability must be declared in this file.
/// ============================================================
abstract final class Capabilities {
  Capabilities._();

  // ── Marketplace ──
  static const marketplaceListings = Capability(
    id: 'marketplace.listings',
    name: 'Marketplace Listings',
    description: 'Create and manage marketplace product listings',
    domain: 'marketplace',
  );

  static const marketplaceOrders = Capability(
    id: 'marketplace.orders',
    name: 'Marketplace Orders',
    description: 'Process and manage marketplace orders',
    domain: 'marketplace',
  );

  // ── Inventory ──
  static const inventoryStock = Capability(
    id: 'inventory.stock',
    name: 'Inventory Stock',
    description: 'Track and manage inventory stock levels',
    domain: 'inventory',
  );

  static const inventoryWarehouse = Capability(
    id: 'inventory.warehouse',
    name: 'Warehouse Management',
    description: 'Manage warehouse operations and storage',
    domain: 'inventory',
  );

  // ── Workflow ──
  static const workflowExecution = Capability(
    id: 'workflow.execution',
    name: 'Workflow Execution',
    description: 'Execute multi-stage activity workflows',
    domain: 'workflow',
  );

  // ── Finance ──
  static const financeRecording = Capability(
    id: 'finance.recording',
    name: 'Financial Recording',
    description: 'Record financial transactions',
    domain: 'finance',
  );

  static const financeInvoicing = Capability(
    id: 'finance.invoicing',
    name: 'Invoicing',
    description: 'Generate and manage invoices',
    domain: 'finance',
  );

  // ── Analytics ──
  static const analyticsBasic = Capability(
    id: 'analytics.basic',
    name: 'Basic Analytics',
    description: 'View basic analytics dashboards',
    domain: 'analytics',
  );

  static const analyticsAdvanced = Capability(
    id: 'analytics.advanced',
    name: 'Advanced Analytics',
    description: 'Access advanced analytics and reporting',
    domain: 'analytics',
  );

  // ── Traceability ──
  static const traceabilityBasic = Capability(
    id: 'traceability.basic',
    name: 'Basic Traceability',
    description: 'View product traceability information',
    domain: 'traceability',
  );

  static const traceabilityExport = Capability(
    id: 'traceability.export',
    name: 'Traceability Export',
    description: 'Export traceability records',
    domain: 'traceability',
  );

  // ── Logistics ──
  static const logisticsDispatch = Capability(
    id: 'logistics.dispatch',
    name: 'Dispatch Management',
    description: 'Manage product dispatch operations',
    domain: 'logistics',
  );

  static const logisticsTracking = Capability(
    id: 'logistics.tracking',
    name: 'Shipment Tracking',
    description: 'Track shipments in real time',
    domain: 'logistics',
  );

  // ── Staff ──
  static const staffManagement = Capability(
    id: 'staff.management',
    name: 'Staff Management',
    description: 'Manage staff and team members',
    domain: 'staff',
  );

  // ── Cold Chain ──
  static const coldchainMonitoring = Capability(
    id: 'coldchain.monitoring',
    name: 'Cold Chain Monitoring',
    description: 'Monitor cold chain temperature data',
    domain: 'coldchain',
  );

  // ── AI ──
  static const aiRecommendations = Capability(
    id: 'ai.recommendations',
    name: 'AI Recommendations',
    description: 'Access AI-powered recommendations',
    domain: 'ai',
  );

  // ── Spatial ──
  static const spatialView = Capability(
    id: 'spatial.view',
    name: 'Spatial View',
    description: 'View spatial assets and boundaries',
    domain: 'spatial',
  );

  static const spatialCapture = Capability(
    id: 'spatial.capture',
    name: 'Spatial Capture',
    description: 'Capture GPS boundary points',
    domain: 'spatial',
  );

  static const spatialEdit = Capability(
    id: 'spatial.edit',
    name: 'Spatial Edit',
    description: 'Edit spatial asset metadata and boundaries',
    domain: 'spatial',
  );

  static const spatialAnalytics = Capability(
    id: 'spatial.analytics',
    name: 'Spatial Analytics',
    description: 'Access spatial analytics and overlap detection',
    domain: 'spatial',
  );

  static const carbonSpatial = Capability(
    id: 'carbon.spatial',
    name: 'Carbon Spatial',
    description: 'Carbon project spatial mapping and monitoring',
    domain: 'carbon',
  );

  static const traceabilitySpatial = Capability(
    id: 'traceability.spatial',
    name: 'Traceability Spatial',
    description: 'Traceability spatial mapping and location tracking',
    domain: 'traceability',
  );

  // ── All Registered Capabilities ──
  static const List<Capability> all = [
    marketplaceListings,
    marketplaceOrders,
    inventoryStock,
    inventoryWarehouse,
    workflowExecution,
    financeRecording,
    financeInvoicing,
    analyticsBasic,
    analyticsAdvanced,
    traceabilityBasic,
    traceabilityExport,
    logisticsDispatch,
    logisticsTracking,
    staffManagement,
    coldchainMonitoring,
    aiRecommendations,
    spatialView,
    spatialCapture,
    spatialEdit,
    spatialAnalytics,
    carbonSpatial,
    traceabilitySpatial,
  ];

  /// Look up a capability by its id.
  static Capability? byId(String id) {
    for (final capability in all) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  /// Get all capabilities for a given domain.
  static List<Capability> forDomain(String domain) {
    return all.where((c) => c.domain == domain).toList();
  }
}
