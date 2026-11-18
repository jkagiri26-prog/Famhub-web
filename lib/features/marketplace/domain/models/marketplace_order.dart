/// Lifecycle of a marketplace order.
///
/// The backend stores the existing canonical `commerce.orders.status` values.
/// Payment state is deliberately not part of this lifecycle.
enum MarketplaceOrderStatus {
  pending,
  accepted,
  confirmed,
  rejected,
  fulfilled,
  cancelled,
  returned,
  inProgress,
  unknown;

  static MarketplaceOrderStatus fromBackend(String? value) {
    return switch (value) {
      'pending' => MarketplaceOrderStatus.pending,
      'accepted' => MarketplaceOrderStatus.accepted,
      'confirmed' => MarketplaceOrderStatus.confirmed,
      'delivered' => MarketplaceOrderStatus.fulfilled,
      'rejected' => MarketplaceOrderStatus.rejected,
      'cancelled' => MarketplaceOrderStatus.cancelled,
      'returned' => MarketplaceOrderStatus.returned,
      'shipped' => MarketplaceOrderStatus.inProgress,
      _ => MarketplaceOrderStatus.unknown,
    };
  }

  String get label {
    return switch (this) {
      MarketplaceOrderStatus.pending => 'Pending seller acceptance',
      MarketplaceOrderStatus.accepted => 'Accepted',
      MarketplaceOrderStatus.confirmed => 'Fulfilment confirmed',
      MarketplaceOrderStatus.rejected => 'Rejected',
      MarketplaceOrderStatus.fulfilled => 'Fulfilled',
      MarketplaceOrderStatus.cancelled => 'Cancelled',
      MarketplaceOrderStatus.returned => 'Returned',
      MarketplaceOrderStatus.inProgress => 'Shipped',
      MarketplaceOrderStatus.unknown => 'Status unavailable',
    };
  }
}

/// Buyer-facing order read model backed by the canonical `commerce.orders`
/// row. Amounts, currency and status are never recomputed on the client.
class MarketplaceOrder {
  final String id;
  final String listingId;
  final String buyerEntityId;
  final String sellerEntityId;
  final double quantity;
  final double totalAmount;
  final String currency;
  final MarketplaceOrderStatus status;
  final String rawStatus;
  final DateTime? createdAt;

  const MarketplaceOrder({
    required this.id,
    required this.listingId,
    required this.buyerEntityId,
    required this.sellerEntityId,
    required this.quantity,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.rawStatus,
    this.createdAt,
  });

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? '';
    return MarketplaceOrder(
      id: json['id']?.toString() ?? '',
      listingId: json['listing_id']?.toString() ?? '',
      buyerEntityId: json['buyer_entity_id']?.toString() ?? '',
      sellerEntityId: json['seller_entity_id']?.toString() ?? '',
      quantity: _asDouble(json['quantity']),
      totalAmount: _asDouble(json['total_amount']),
      currency: json['currency']?.toString() ?? 'KES',
      status: MarketplaceOrderStatus.fromBackend(rawStatus),
      rawStatus: rawStatus,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
