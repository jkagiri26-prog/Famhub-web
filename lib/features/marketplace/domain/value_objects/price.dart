/// ============================================================
/// PRICE VALUE OBJECT
/// ============================================================
///
/// Immutable value object representing a monetary price.
/// ============================================================
library;

class Price {
  final double amount;
  final String currency;

  const Price({
    required this.amount,
    this.currency = 'KSh',
  });

  bool get isZero => amount == 0;
  bool get isPositive => amount > 0;

  Price operator +(Price other) {
    return Price(amount: amount + other.amount, currency: currency);
  }

  Price operator *(double multiplier) {
    return Price(amount: amount * multiplier, currency: currency);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Price &&
          amount == other.amount &&
          currency == other.currency;

  @override
  int get hashCode => amount.hashCode ^ currency.hashCode;

  @override
  String toString() => '$currency ${amount.toStringAsFixed(2)}';
}
