import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/marketplace_order.dart';

/// Buyer action hosted by the existing listing details flow.
///
/// The client never sends buyer/seller ids, price, currency or stock identity.
/// It sends only quantity and an idempotency key to the canonical RPC.
class BuyOrderSection extends ConsumerStatefulWidget {
  final Listing listing;

  const BuyOrderSection({super.key, required this.listing});

  @override
  ConsumerState<BuyOrderSection> createState() => _BuyOrderSectionState();
}

class _BuyOrderSectionState extends ConsumerState<BuyOrderSection> {
  Future<void> _placeOrder() async {
    final quantity = await _promptQuantity();
    if (quantity == null || !mounted) return;

    await ref
        .read(buyerOrderControllerProvider.notifier)
        .placeOrder(listingId: widget.listing.id, quantity: quantity);

    if (!mounted) return;
    final state = ref.read(buyerOrderControllerProvider);
    if (state is BuyerOrderSuccess) {
      await _showOrderCreated(state.order);
    } else if (state is BuyerOrderFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<double?> _promptQuantity() async {
    final controller = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Place order'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.listing.title} · '
                '${widget.listing.displayPrice}',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffixText: widget.listing.unitName,
                  helperText:
                      '${widget.listing.availableQuantity.toStringAsFixed(0)} '
                      '${widget.listing.unitName ?? ''} available',
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a quantity greater than zero.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(
                dialogContext,
              ).pop(double.parse(controller.text.trim()));
            },
            child: const Text('Place order'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showOrderCreated(MarketplaceOrder order) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order placed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.quantity.toStringAsFixed(0)} unit(s) · '
              '${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text('Order: ${order.id}'),
            const SizedBox(height: 16),
            _OrderStatusLine(orderId: order.id, initial: order),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(buyerOrderControllerProvider.notifier).reset();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAuthenticatedProvider)) return const SizedBox.shrink();
    if (widget.listing.status != ListingStatus.active) {
      return const SizedBox.shrink();
    }
    if (widget.listing.isSoldOut) return const SizedBox.shrink();

    final activeEntityId = ref.watch(
      contextProvider.select((context) => context.entityId),
    );
    if (activeEntityId == widget.listing.entityId) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(buyerOrderControllerProvider);
    final isLoading = state is BuyerOrderLoading;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buy from this listing',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'The server confirms the current price, currency and available '
              'stock before creating the order.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isLoading ? null : _placeOrder,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart_checkout, size: 18),
              label: Text(isLoading ? 'Placing order…' : 'Buy / Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusLine extends ConsumerStatefulWidget {
  final String orderId;
  final MarketplaceOrder initial;

  const _OrderStatusLine({required this.orderId, required this.initial});

  @override
  ConsumerState<_OrderStatusLine> createState() => _OrderStatusLineState();
}

class _OrderStatusLineState extends ConsumerState<_OrderStatusLine> {
  bool _cancelling = false;
  bool _delivering = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'The seller will see the order as cancelled and the reserved stock '
          'will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .cancelListingOrder(orderId: widget.orderId);
      if (!mounted) return;
      ref.invalidate(buyerOrderDetailsProvider(widget.orderId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order cancelled.')));
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().toLowerCase();
      final message = text.contains('cannot be cancelled')
          ? 'This order can no longer be cancelled.'
          : 'The order could not be cancelled. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _confirmDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm delivery?'),
        content: const Text(
          'Confirm that you received this order. This does not change payment '
          'or stock state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _delivering = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .confirmListingOrderDelivery(orderId: widget.orderId);
      if (!mounted) return;
      ref.invalidate(buyerOrderDetailsProvider(widget.orderId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery confirmed.')));
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().toLowerCase();
      final message = text.contains('cannot be delivered')
          ? 'This order is not eligible for delivery confirmation.'
          : 'Delivery could not be confirmed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _delivering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(buyerOrderDetailsProvider(widget.orderId));

    return orderAsync.when(
      loading: () => Text('Status: ${widget.initial.status.label}'),
      error: (_, __) => Text('Status: ${widget.initial.status.label}'),
      data: (order) {
        final current = order ?? widget.initial;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Status: ${current.status.label}')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(buyerOrderDetailsProvider(widget.orderId));
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (current.status == MarketplaceOrderStatus.pending) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancel,
                icon: _cancelling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: 16),
                label: Text(_cancelling ? 'Cancelling…' : 'Cancel order'),
              ),
            ],
            if (current.status == MarketplaceOrderStatus.inProgress) ...[
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: _delivering ? null : _confirmDelivery,
                icon: _delivering
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(_delivering ? 'Confirming…' : 'Confirm delivery'),
              ),
            ],
          ],
        );
      },
    );
  }
}
