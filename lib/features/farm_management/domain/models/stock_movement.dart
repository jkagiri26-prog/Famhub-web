/// ============================================================
/// STOCK MOVEMENT MODEL
/// ============================================================
///
/// Represents a stock movement record for persistence.
/// Used by the stock mutation engine to log inventory changes.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/stock_direction.dart';

/// Stock movement record for persistence.
class StockMovement {
  final String? id;
  final String farmId;
  final String? assetId;
  final String? activityId;
  final StockDirection direction;
  final double quantity;
  final String? unitId;
  final String? description;
  final DateTime timestamp;

  const StockMovement({
    this.id,
    required this.farmId,
    this.assetId,
    this.activityId,
    required this.direction,
    required this.quantity,
    this.unitId,
    this.description,
    required this.timestamp,
  });
}
