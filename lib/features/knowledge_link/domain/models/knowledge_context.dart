/// ============================================================
/// KNOWLEDGE CONTEXT (CANONICAL, MODULE-NEUTRAL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/domain/models/
///
/// A canonical, module-neutral description of "what the user is currently
/// working with". It is deliberately NOT a workspace/entity context:
///
///   - Entity context  = WHO is operating (handled elsewhere).
///   - Knowledge context = WHAT the subject is (this model).
///
/// Any module (Farm Management, Trader/Business Hub, Marketplace,
/// Agri Connect, Services, …) builds one of these from whatever canonical
/// identifiers it already holds and hands it to the Knowledge Link surface.
/// Knowledge Link then resolves matching curated resources via the backend
/// resolver — no module-specific branching happens inside Knowledge Link.
///
/// Every field is optional. `topicId` is reserved for future use — the
/// current `public.resolve_knowledge_resources` resolver does not yet
/// support topic matching.
/// ============================================================
library;

class KnowledgeContext {
  /// `core.items.id` (crop/product kind).
  final String? itemId;

  /// `core.item_variants.id` (crop variety / product variant / livestock).
  final String? variantId;

  /// `core.commodities.id`.
  final String? commodityId;

  /// `farm_management.activity_types.id` (current operational activity).
  final String? activityTypeId;

  /// `core.locations.id` (county / sub-county / ward / business location).
  final String? locationId;

  /// `knowledge.resource_types.code` (e.g. 'quick_guide', 'general_guide').
  /// Optional — null means "all resource types".
  final String? resourceTypeCode;

  /// `knowledge.topics.id` — RESERVED for future use. The current resolver
  /// does not support topic matching, so this is accepted but ignored.
  final String? topicId;

  const KnowledgeContext({
    this.itemId,
    this.variantId,
    this.commodityId,
    this.activityTypeId,
    this.locationId,
    this.resourceTypeCode,
    this.topicId,
  });

  /// True when no canonical identifier is present at all.
  bool get isEmpty =>
      itemId == null &&
      variantId == null &&
      commodityId == null &&
      activityTypeId == null &&
      locationId == null &&
      resourceTypeCode == null &&
      topicId == null;

  bool get isNotEmpty => !isEmpty;

  KnowledgeContext copyWith({
    String? itemId,
    String? variantId,
    String? commodityId,
    String? activityTypeId,
    String? locationId,
    String? resourceTypeCode,
    String? topicId,
    bool clearItemId = false,
    bool clearVariantId = false,
    bool clearCommodityId = false,
    bool clearActivityTypeId = false,
    bool clearLocationId = false,
    bool clearResourceTypeCode = false,
    bool clearTopicId = false,
  }) {
    return KnowledgeContext(
      itemId: clearItemId ? null : itemId ?? this.itemId,
      variantId: clearVariantId ? null : variantId ?? this.variantId,
      commodityId: clearCommodityId ? null : commodityId ?? this.commodityId,
      activityTypeId:
          clearActivityTypeId ? null : activityTypeId ?? this.activityTypeId,
      locationId: clearLocationId ? null : locationId ?? this.locationId,
      resourceTypeCode: clearResourceTypeCode
          ? null
          : resourceTypeCode ?? this.resourceTypeCode,
      topicId: clearTopicId ? null : topicId ?? this.topicId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeContext &&
          itemId == other.itemId &&
          variantId == other.variantId &&
          commodityId == other.commodityId &&
          activityTypeId == other.activityTypeId &&
          locationId == other.locationId &&
          resourceTypeCode == other.resourceTypeCode &&
          topicId == other.topicId;

  @override
  int get hashCode => Object.hash(itemId, variantId, commodityId,
      activityTypeId, locationId, resourceTypeCode, topicId);

  @override
  String toString() => 'KnowledgeContext(itemId: $itemId, '
      'variantId: $variantId, commodityId: $commodityId, '
      'activityTypeId: $activityTypeId, locationId: $locationId, '
      'resourceTypeCode: $resourceTypeCode, topicId: $topicId)';
}
