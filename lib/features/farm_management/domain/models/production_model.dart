/// Represents a single production record from `farm.production_records`.
///
/// Schema source (relevant columns):
///   farm.production_records:
///     - id (uuid)
///     - farm_id (uuid)
///     - activity_id (uuid, nullable)
///     - variant_id (uuid, nullable)
///     - quantity (numeric, nullable; constrained >= 0)
///     - unit_id (uuid, nullable)
///     - category_id (uuid, nullable)
///     - asset_id (uuid, nullable)
///     - field_id (uuid, nullable)
class ProductionModel {
  final String id;
  final String farmId;
  final String? activityId;
  final String? variantId;
  final double? quantity;
  final String? unitId;
  final String? categoryId;
  final String? assetId;
  final String? fieldId;

  const ProductionModel({
    required this.id,
    required this.farmId,
    this.activityId,
    this.variantId,
    this.quantity,
    this.unitId,
    this.categoryId,
    this.assetId,
    this.fieldId,
  });
}

