/// ============================================================
/// QUANTITY VALUE OBJECT
/// ============================================================
///
/// Immutable value object representing a measurable quantity with unit.
/// ============================================================
library;

class Quantity {
  final double value;
  final String unit;

  const Quantity({
    required this.value,
    required this.unit,
  });

  bool get isZero => value <= 0;
  bool isLowStock(double threshold) => value <= threshold && value > 0;

  Quantity operator -(Quantity other) {
    return Quantity(value: value - other.value, unit: unit);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quantity &&
          value == other.value &&
          unit == other.unit;

  @override
  int get hashCode => value.hashCode ^ unit.hashCode;

  @override
  String toString() => '${value.toStringAsFixed(1)} $unit';
}
