/// ============================================================
/// POLICY — LOCATION-BASED RULE CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/domain/ = policy domain models
///
/// A PolicyRule represents a single location policy declaration.
/// Policies define what IS ALLOWED in this specific location.
///
/// Policies are NOT capabilities (what an org CAN do).
/// Policies are NOT feature flags (runtime enable/disable).
/// Policies are NOT access decisions (what user is permitted).
///
/// Policy = What is ALLOWED in this location.
///
/// ✅ Responsibilities:
///   - Define a unique policy rule key
///   - Own the rule's expected value type
///   - Pure declaration — no business logic
///
/// ❌ Does NOT:
///   - Evaluate rules
///   - Check capabilities
///   - Reference organization types
///   - Import UI
/// ============================================================
library;

/// ============================================================
/// POLICY RULE IDENTIFIER
/// ============================================================
///
/// Every policy rule is identified by a unique dot-separated string.
/// The format follows: <domain>.<rule>
///
/// Examples:
///   workflow.execution
///   marketplace.selling
///   upload.max_images
/// ============================================================
class Policy {
  /// Unique dot-separated identifier
  final String id;

  /// Human-readable name
  final String name;

  /// Description of what this rule controls
  final String description;

  /// Domain grouping (e.g., 'workflow', 'marketplace', 'upload')
  final String domain;

  /// Expected value type (bool, int, double, String, List<String>)
  final String valueType;

  const Policy({
    required this.id,
    required this.name,
    required this.description,
    required this.domain,
    this.valueType = 'bool',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Policy &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Policy($id)';
}

/// ============================================================
/// POLICY CONSTANTS
/// ============================================================
///
/// All known policy rules are defined here as static constants.
/// Every system policy must be declared in this file.
/// ============================================================
abstract final class Policies {
  Policies._();

  // ── Workflow ──
  static const workflowExecution = Policy(
    id: 'workflow.execution',
    name: 'Workflow Execution',
    description: 'Allow workflow execution in this location',
    domain: 'workflow',
  );

  // ── Inventory ──
  static const inventoryTracking = Policy(
    id: 'inventory.tracking',
    name: 'Inventory Tracking',
    description: 'Allow inventory tracking in this location',
    domain: 'inventory',
  );

  // ── Marketplace ──
  static const marketplaceSelling = Policy(
    id: 'marketplace.selling',
    name: 'Marketplace Selling',
    description: 'Allow selling on marketplace in this location',
    domain: 'marketplace',
  );

  static const marketplaceBuying = Policy(
    id: 'marketplace.buying',
    name: 'Marketplace Buying',
    description: 'Allow buying on marketplace in this location',
    domain: 'marketplace',
  );

  static const marketplaceOrders = Policy(
    id: 'marketplace.orders',
    name: 'Marketplace Orders',
    description: 'Allow marketplace order processing in this location',
    domain: 'marketplace',
  );

  // ── Upload ──
  static const maxImageUpload = Policy(
    id: 'upload.max_images',
    name: 'Max Image Upload',
    description: 'Maximum number of images allowed per upload',
    domain: 'upload',
    valueType: 'int',
  );

  // ── Traceability ──
  static const traceability = Policy(
    id: 'traceability.enabled',
    name: 'Traceability',
    description: 'Allow traceability features in this location',
    domain: 'traceability',
  );

  // ── Finance ──
  static const financeRecording = Policy(
    id: 'finance.recording',
    name: 'Financial Recording',
    description: 'Allow financial recording in this location',
    domain: 'finance',
  );

  // ── Analytics ──
  static const analytics = Policy(
    id: 'analytics.enabled',
    name: 'Analytics',
    description: 'Allow analytics features in this location',
    domain: 'analytics',
  );

  // ── AI ──
  static const aiAssistant = Policy(
    id: 'ai.assistant',
    name: 'AI Assistant',
    description: 'Allow AI assistant in this location',
    domain: 'ai',
  );

  // ── Staff ──
  static const staffManagement = Policy(
    id: 'staff.management',
    name: 'Staff Management',
    description: 'Allow staff management in this location',
    domain: 'staff',
  );

  // ── Export ──
  static const exportCertification = Policy(
    id: 'export.certification',
    name: 'Export Certification',
    description: 'Allow export certification in this location',
    domain: 'export',
  );

  // ── Cold Chain ──
  static const coldChain = Policy(
    id: 'coldchain.enabled',
    name: 'Cold Chain',
    description: 'Allow cold chain monitoring in this location',
    domain: 'coldchain',
  );

  // ── Logistics ──
  static const logistics = Policy(
    id: 'logistics.enabled',
    name: 'Logistics',
    description: 'Allow logistics features in this location',
    domain: 'logistics',
  );

  // ── Contract Farming ──
  static const contractFarming = Policy(
    id: 'contract.farming',
    name: 'Contract Farming',
    description: 'Allow contract farming in this location',
    domain: 'contract',
  );

  // ── Region ──
  static const regionRestriction = Policy(
    id: 'region.restriction',
    name: 'Region Restriction',
    description: 'Region-specific restriction rules',
    domain: 'region',
    valueType: 'List<String>',
  );

  // ── Spatial ──
  static const allowBoundaryCapture = Policy(
    id: 'spatial.boundary_capture',
    name: 'Allow Boundary Capture',
    description: 'Allow GPS boundary capture in this location',
    domain: 'spatial',
  );

  static const allowAreaEdit = Policy(
    id: 'spatial.area_edit',
    name: 'Allow Area Edit',
    description: 'Allow editing area values in this location',
    domain: 'spatial',
  );

  static const allowOverlapAnalysis = Policy(
    id: 'spatial.overlap_analysis',
    name: 'Allow Overlap Analysis',
    description: 'Allow overlap detection in this location',
    domain: 'spatial',
  );

  static const allowGpsCapture = Policy(
    id: 'spatial.gps_capture',
    name: 'Allow GPS Capture',
    description: 'Allow GPS coordinate capture in this location',
    domain: 'spatial',
  );

  static const allowCarbonMapping = Policy(
    id: 'carbon.mapping',
    name: 'Allow Carbon Mapping',
    description: 'Allow carbon project spatial mapping in this location',
    domain: 'carbon',
  );

  static const allowTraceabilityMapping = Policy(
    id: 'traceability.mapping',
    name: 'Allow Traceability Mapping',
    description: 'Allow traceability spatial mapping in this location',
    domain: 'traceability',
  );

  // ── All Registered Policies ──
  static const List<Policy> all = [
    workflowExecution,
    inventoryTracking,
    marketplaceSelling,
    marketplaceBuying,
    marketplaceOrders,
    maxImageUpload,
    traceability,
    financeRecording,
    analytics,
    aiAssistant,
    staffManagement,
    exportCertification,
    coldChain,
    logistics,
    contractFarming,
    regionRestriction,
    allowBoundaryCapture,
    allowAreaEdit,
    allowOverlapAnalysis,
    allowGpsCapture,
    allowCarbonMapping,
    allowTraceabilityMapping,
  ];

  /// Look up a policy by its id.
  static Policy? byId(String id) {
    for (final policy in all) {
      if (policy.id == id) return policy;
    }
    return null;
  }

  /// Get all policies for a given domain.
  static List<Policy> forDomain(String domain) {
    return all.where((p) => p.domain == domain).toList();
  }
}
