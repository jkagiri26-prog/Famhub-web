/// Represents a single production record from `farm.production_records`.
///
/// Schema source (relevant columns):
///   farm.production_records:
///     - id (uuid)
///     - farm_id (uuid)
///     - activity_id (uuid, nullable)
///     - variant_id (uuid, nullable)
///     - output_commodity_id (uuid, nullable → core.commodities.id)
///     - quantity (numeric, nullable; constrained >= 0)
///     - unit_id (uuid, nullable)
class ProductionEntity {
  final String id;
  final String? activityId;
  final String? variantId;
  final String? outputCommodityId;
  final double? quantity;
  final String? unitId;
  final String? categoryId;
  final String? assetId;
  final String? fieldId;
  final String? sourceType;

  const ProductionEntity({
    required this.id,
    this.activityId,
    this.variantId,
    this.outputCommodityId,
    this.quantity,
    this.unitId,
    this.categoryId,
    this.assetId,
    this.fieldId,
    this.sourceType,
  });
}

