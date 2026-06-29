/// ============================================================
/// STOCK DIRECTION ENUM
/// ============================================================
///
/// Direction of stock movement in inventory operations.
/// ============================================================
library;

/// Direction of stock movement.
enum StockDirection {
  /// Stock flows INTO inventory (production, purchase)
  inflow,

  /// Stock flows OUT OF inventory (consumption, sale)
  outflow,

  /// Stock is adjusted (correction, loss)
  adjustment,
}
