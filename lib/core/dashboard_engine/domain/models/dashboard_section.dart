/// ============================================================
/// DASHBOARD SECTION (DOMAIN CORE)
/// ============================================================
///
/// Represents a named grouping of dashboard widgets.
/// Sections are defined by backend metadata.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/domain/models/ = domain models
///
/// ✅ Responsibilities:
///   - Pure data model for dashboard sections
///   - Maps backend section definitions to runtime
///
/// ❌ Does NOT:
///   - Contain UI logic
///   - Reference registries
///   - Import Flutter widgets
/// ============================================================
class DashboardSection {
  /// Unique section identifier
  final String sectionKey;

  /// Human-readable section name
  final String displayName;

  /// Section description (optional)
  final String? description;

  /// Display order for section placement
  final int displayOrder;

  /// Icon key for section header
  final String iconKey;

  /// Whether section is visible
  final bool isVisible;

  /// Maximum number of widgets in this section (0 = unlimited)
  final int maxWidgets;

  /// Layout style for this section (grid, list, carousel, etc.)
  final String layoutStyle;

  /// Minimum role level required to see this section
  final String? requiredRole;

  /// Whether section requires a specific entity type
  final String? requiredEntityType;

  const DashboardSection({
    required this.sectionKey,
    required this.displayName,
    this.description,
    required this.displayOrder,
    this.iconKey = 'widgets',
    this.isVisible = true,
    this.maxWidgets = 0,
    this.layoutStyle = 'grid',
    this.requiredRole,
    this.requiredEntityType,
  });

  factory DashboardSection.fromMap(Map<String, dynamic> map) {
    return DashboardSection(
      sectionKey: map['section_key']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Section',
      description: map['description']?.toString(),
      displayOrder: map['display_order'] ?? 0,
      iconKey: map['icon_key']?.toString() ?? 'widgets',
      isVisible: map['is_visible'] ?? true,
      maxWidgets: map['max_widgets'] ?? 0,
      layoutStyle: map['layout_style']?.toString() ?? 'grid',
      requiredRole: map['required_role']?.toString(),
      requiredEntityType: map['required_entity_type']?.toString(),
    );
  }

  @override
  String toString() => 'DashboardSection($sectionKey: $displayName)';
}
