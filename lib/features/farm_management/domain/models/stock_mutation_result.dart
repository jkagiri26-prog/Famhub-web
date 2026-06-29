/// ============================================================
/// STOCK MUTATION RESULT
/// ============================================================
///
/// Result model returned after a stock mutation operation.
/// Indicates success/failure and provides the new balance.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/stock_direction.dart';

/// Result of a stock mutation operation.
class StockMutationResult {
  final String assetId;
  final StockDirection direction;
  final double quantity;
  final double newBalance;
  final bool success;
  final String? errorMessage;

  const StockMutationResult({
    required this.assetId,
    required this.direction,
    required this.quantity,
    required this.newBalance,
    required this.success,
    this.errorMessage,
  });
}
