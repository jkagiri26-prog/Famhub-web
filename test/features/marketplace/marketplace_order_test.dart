import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/models/marketplace_order.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';

class _FakeOrderRepository implements MarketplaceRepository {
  final List<({String listingId, double quantity, String key})> creates = [];
  final List<String> reads = [];
  final List<String> cancels = [];
  Completer<void>? hold;
  Object? throwOnCreate;
  MarketplaceOrder? order;
  MarketplaceOrder? readOrder;

  @override
  Future<MarketplaceOrder> createListingOrder({
    required String listingId,
    required double quantity,
    required String idempotencyKey,
  }) async {
    creates.add((
      listingId: listingId,
      quantity: quantity,
      key: idempotencyKey,
    ));
    if (hold != null) await hold!.future;
    if (throwOnCreate != null) throw throwOnCreate!;
    return order ??
        MarketplaceOrder(
          id: 'order-1',
          listingId: listingId,
          buyerEntityId: 'buyer-entity',
          sellerEntityId: 'seller-entity',
          quantity: quantity,
          totalAmount: quantity * 100,
          currency: 'KES',
          status: MarketplaceOrderStatus.pending,
          rawStatus: 'pending',
          createdAt: DateTime(2026, 11, 18),
        );
  }

  @override
  Future<MarketplaceOrder?> fetchBuyerOrder(String orderId) async {
    reads.add(orderId);
    return readOrder;
  }

  @override
  Future<MarketplaceOrder> cancelListingOrder({
    required String orderId,
    String? reason,
  }) async {
    cancels.add(orderId);
    return MarketplaceOrder.fromJson({
      'id': orderId,
      'listing_id': 'listing-1',
      'buyer_entity_id': 'buyer-entity',
      'seller_entity_id': 'seller-entity',
      'quantity': 10,
      'total_amount': 1000,
      'currency': 'KES',
      'status': 'cancelled',
      'created_at': '2026-11-18T10:00:00Z',
    });
  }

  @override
  Future<MarketplaceOrder> confirmListingOrderDelivery({
    required String orderId,
    String? reason,
  }) async {
    return MarketplaceOrder.fromJson({
      'id': orderId,
      'listing_id': 'listing-1',
      'buyer_entity_id': 'buyer-entity',
      'seller_entity_id': 'seller-entity',
      'quantity': 10,
      'total_amount': 1000,
      'currency': 'KES',
      'status': 'delivered',
      'created_at': '2026-11-18T10:00:00Z',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MarketplaceOrder _order({
  String status = 'pending',
  double total = 2500,
  String currency = 'KES',
}) {
  return MarketplaceOrder.fromJson({
    'id': 'order-1',
    'listing_id': 'listing-1',
    'buyer_entity_id': 'buyer-entity',
    'seller_entity_id': 'seller-entity',
    'quantity': 10,
    'total_amount': total,
    'currency': currency,
    'status': status,
    'created_at': '2026-11-18T10:00:00Z',
  });
}

void main() {
  group('MarketplaceOrder', () {
    test('maps canonical acceptance/fulfilment statuses', () {
      expect(_order(status: 'pending').status, MarketplaceOrderStatus.pending);
      expect(
        _order(status: 'accepted').status,
        MarketplaceOrderStatus.accepted,
      );
      expect(
        _order(status: 'confirmed').status,
        MarketplaceOrderStatus.confirmed,
      );
      expect(
        _order(status: 'delivered').status,
        MarketplaceOrderStatus.fulfilled,
      );
      expect(
        _order(status: 'cancelled').status,
        MarketplaceOrderStatus.cancelled,
      );
      expect(
        _order(status: 'returned').status,
        MarketplaceOrderStatus.returned,
      );
    });

    test('preserves server-authored total and currency', () {
      final order = _order(status: 'pending', total: 3250, currency: 'UGX');
      expect(order.totalAmount, 3250);
      expect(order.currency, 'UGX');
      expect(order.quantity, 10);
    });
  });

  group('BuyerOrderController', () {
    test(
      'exposes loading then success and sends no client-owned data',
      () async {
        final repo = _FakeOrderRepository();
        repo.hold = Completer<void>();
        final container = ProviderContainer(
          overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        final future = container
            .read(buyerOrderControllerProvider.notifier)
            .placeOrder(listingId: 'listing-1', quantity: 10);

        expect(
          container.read(buyerOrderControllerProvider),
          isA<BuyerOrderLoading>(),
        );
        expect(repo.creates.single.listingId, 'listing-1');
        expect(repo.creates.single.quantity, 10);
        expect(repo.creates.single.key, isNotEmpty);

        repo.hold!.complete();
        await future;

        final state = container.read(buyerOrderControllerProvider);
        expect(state, isA<BuyerOrderSuccess>());
        expect((state as BuyerOrderSuccess).order.currency, 'KES');
      },
    );

    test('maps insufficient stock to a buyer-safe failure', () async {
      final repo = _FakeOrderRepository()
        ..throwOnCreate = Exception('insufficient available stock');
      final container = ProviderContainer(
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(buyerOrderControllerProvider.notifier)
          .placeOrder(listingId: 'listing-1', quantity: 10);

      final state = container.read(buyerOrderControllerProvider);
      expect(state, isA<BuyerOrderFailure>());
      expect(
        (state as BuyerOrderFailure).message,
        'There is not enough stock available for that quantity.',
      );
    });

    test('does not start a second request while loading', () async {
      final repo = _FakeOrderRepository()..hold = Completer<void>();
      final container = ProviderContainer(
        overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final first = container
          .read(buyerOrderControllerProvider.notifier)
          .placeOrder(listingId: 'listing-1', quantity: 1);
      final second = container
          .read(buyerOrderControllerProvider.notifier)
          .placeOrder(listingId: 'listing-1', quantity: 2);

      expect(repo.creates.length, 1);
      repo.hold!.complete();
      await Future.wait([first, second]);
    });
  });

  group('Marketplace order migration contract', () {
    final source = File(
      'supabase/migrations/20261118000001_marketplace_order_foundation.sql',
    ).readAsStringSync();

    test('creates the canonical buyer server-side function', () {
      expect(
        source,
        contains(
          'FUNCTION commerce.create_listing_order(\n'
          '  p_listing_id uuid,\n'
          '  p_quantity numeric,\n'
          '  p_idempotency_key text\n'
          ')',
        ),
      );
      expect(source, contains('SECURITY DEFINER'));
      expect(
        source,
        contains(
          "SET search_path TO 'pg_catalog', 'commerce', 'core', "
          "'marketplace', 'users'",
        ),
      );
      expect(
        source,
        contains('GRANT EXECUTE ON FUNCTION commerce.create_listing_order'),
      );
    });

    test('rejects inactive listing, inactive seller and invalid quantity', () {
      expect(source, contains('listing not found or inactive'));
      expect(source, contains('seller is inactive'));
      expect(source, contains('quantity must be greater than zero'));
      expect(source, contains('two decimal places'));
      expect(source, contains('insufficient available stock'));
    });

    test(
      'derives all buyer/seller/price/currency/stock values server-side',
      () {
        expect(
          source,
          contains('v_buyer_entity_id := core.get_active_entity()'),
        );
        expect(source, contains('WHERE o.buyer_id = v_profile_id'));
        expect(source, contains('v_listing.price_per_unit'));
        expect(source, contains('v_listing.currency'));
        expect(
          source,
          contains('WHERE sr.id = v_listing.stock_id\n  FOR UPDATE'),
        );
        expect(source, contains("'pending',\n    'pending',"));
        expect(source, isNot(contains('p_price')));
        expect(source, isNot(contains('p_currency')));
        expect(source, isNot(contains('p_buyer')));
        expect(source, isNot(contains('p_seller')));
      },
    );

    test('uses idempotency and the existing reservation trigger', () {
      expect(source, contains('pg_advisory_xact_lock'));
      expect(source, contains('orders_buyer_idempotency_key_uidx'));
      expect(source, contains('commerce.reserve_stock()'));
      expect(source, contains('INSERT INTO commerce.stock_reservations'));
      expect(source, isNot(contains('UPDATE commerce.stock_registry')));
    });
  });

  group('Marketplace order lifecycle migration contract', () {
    final source = File(
      'supabase/migrations/20261118000002_marketplace_order_lifecycle.sql',
    ).readAsStringSync();

    test('adds accepted/rejected without consuming stock on acceptance', () {
      expect(source, contains("'accepted'"));
      expect(source, contains("'rejected'"));
      expect(source, contains('accepted_at'));
      expect(source, contains('stock_released_at'));
      expect(source, contains('acceptance must preserve the reservation'));
    });

    test('uses a single locked release primitive', () {
      expect(
        source,
        contains('FUNCTION commerce.release_order_stock_reservation'),
      );
      expect(source, contains("r.status = 'reserved'"));
      expect(source, contains('v_reserved_qty < v_release_qty'));
      expect(source, contains("SET status = 'released'"));
      expect(
        source,
        contains('REVOKE ALL ON TABLE commerce.stock_reservations'),
      );
      expect(source, contains('REVOKE UPDATE, DELETE ON commerce.orders'));
    });

    test('requires seller and buyer authorization in SQL', () {
      expect(
        source,
        contains('v_entity_id IS DISTINCT FROM v_order.seller_entity_id'),
      );
      expect(
        source,
        contains('v_profile_id IS DISTINCT FROM v_order.buyer_id'),
      );
      expect(
        source,
        contains('v_entity_id IS DISTINCT FROM v_order.buyer_entity_id'),
      );
      expect(source, contains('order cannot be accepted from status'));
      expect(source, contains('order cannot be rejected from status'));
      expect(source, contains('order cannot be cancelled from status'));
    });

    test('keeps payment state separate', () {
      expect(source, isNot(contains('SET payment_status')));
      expect(source, isNot(contains('commerce.payments')));
    });
  });

  group('Marketplace fulfilment confirmation migration contract', () {
    final source = File(
      'supabase/migrations/20261118000003_marketplace_order_fulfilment_confirmation.sql',
    ).readAsStringSync();

    test('confirms only accepted orders through the canonical trigger', () {
      expect(
        source,
        contains('FUNCTION commerce.confirm_order_fulfilment(uuid)'),
      );
      expect(source, contains("v_order.status <> 'accepted'"));
      expect(source, contains("SET status = 'confirmed'"));
      expect(source, contains('trg_process_order_stock'));
      expect(source, contains('stock_movements'));
      expect(source, contains('stock_reservations'));
      expect(source, contains("SET status = 'consumed'"));
    });

    test('does not mutate physical stock or payment state directly', () {
      expect(source, isNot(contains('UPDATE commerce.stock_registry')));
      expect(source, isNot(contains('SET payment_status')));
      expect(source, isNot(contains('commerce.payments')));
      expect(source, isNot(contains('mpesa')));
    });

    test('rechecks the movement and reservation after the trigger', () {
      expect(source, contains('v_movement_count <> 1'));
      expect(source, contains('v_movement_sum <> -v_reserved_qty'));
      expect(source, contains('reservation was not consumed'));
      expect(source, contains('stock counters became negative'));
    });
  });

  group('Marketplace shipping/delivery migration contract', () {
    final source = File(
      'supabase/migrations/20261118000004_marketplace_order_shipping_delivery.sql',
    ).readAsStringSync();

    test('implements seller shipping and buyer delivery separately', () {
      expect(source, contains('FUNCTION commerce.ship_listing_order('));
      expect(
        source,
        contains('FUNCTION commerce.confirm_listing_order_delivery('),
      );
      expect(source, contains("v_order.status <> 'confirmed'"));
      expect(source, contains("v_order.status <> 'shipped'"));
      expect(source, contains('not authorized to ship this order'));
      expect(
        source,
        contains('not authorized to confirm delivery for this order'),
      );
    });

    test('is status-only and leaves stock/payment untouched', () {
      expect(source, isNot(contains('INSERT INTO commerce.stock_movements')));
      expect(source, isNot(contains('UPDATE commerce.stock_registry')));
      expect(source, isNot(contains('UPDATE commerce.stock_reservations')));
      expect(source, isNot(contains('SET payment_status')));
      expect(source, isNot(contains('commerce.payments')));
      expect(source, isNot(contains('mpesa')));
    });

    test('uses idempotent terminal status replays', () {
      expect(source, contains("IF v_order.status = 'shipped' THEN"));
      expect(source, contains("IF v_order.status = 'delivered' THEN"));
    });
  });
}
