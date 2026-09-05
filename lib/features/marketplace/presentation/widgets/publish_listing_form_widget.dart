import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/stock_item.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'listing_image_picker_area.dart';

/// ============================================================
/// PUBLISH LISTING FORM (MANAGED-STOCK, PHASE 1)
/// ============================================================
///
/// Reusable publish-listing form that accepts a selected managed-stock id.
///
/// ✅ Collects ONLY:
///   - price_per_unit (required)
///   - title          (optional)
///   - description    (optional)
///   - photos         (optional, max 3, WebP ≤ 2 MB each)
///
/// ✅ Read-only display of the selected stock's:
///   - product/variant
///   - available quantity
///   - unit
///   - location
///
/// ✅ On submit:
///   1. Calls marketplace.publish_listing_from_stock(...) with an EMPTY
///      p_images array.
///   2. Uploads each selected photo via the upload_media edge function against
///      the created listing id. The backend attaches them to listing.images.
///
/// ❌ Never inserts into marketplace.listings directly.
/// ❌ Never sends image IDs/paths in p_images.
/// ❌ Never writes listing.images from the client.
/// ❌ Never lets the client submit entity_id / variant_id / unit_id /
///    location_id or a listing quantity.
///
/// Launch points:
///   - Marketplace → Add Listing → stock-selection screen
///   - Farm / Shop / Livestock stock screens (stock_id preselected)
/// ============================================================
class PublishListingFormWidget extends ConsumerStatefulWidget {
  final String stockId;

  /// Optional pre-filled title (e.g. launched from a farm/livestock screen).
  final String? initialTitle;

  const PublishListingFormWidget({
    super.key,
    required this.stockId,
    this.initialTitle,
  });

  @override
  ConsumerState<PublishListingFormWidget> createState() =>
      _PublishListingFormWidgetState();
}

class _PublishListingFormWidgetState
    extends ConsumerState<PublishListingFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SelectedListingImage> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty) {
      _titleController.text = widget.initialTitle!.trim();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(StockItem stock) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        throw const _PublishFailure(
          kind: _PublishFailureKind.invalidPrice,
          message: 'Enter a valid price greater than zero.',
        );
      }

      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      final notifier = ref.read(marketplaceProvider.notifier);
      final report = await notifier.publishListingWithImages(
        stockId: widget.stockId,
        pricePerUnit: price,
        title: title.isEmpty ? null : title,
        description: description.isEmpty ? null : description,
        images: _selectedImages,
      );

      if (!mounted) return;

      if (report.failedCount == 0) {
        final photoNote = report.uploadedCount > 0
            ? ' with ${report.uploadedCount} '
                'photo${report.uploadedCount == 1 ? '' : 's'}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listing published successfully$photoNote'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      _showPartialUploadFailure(report);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final failure = _describeFailure(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${failure.title}: ${failure.message}'),
            backgroundColor: failure.color,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPartialUploadFailure(ListingPublicationReport report) {
    final messenger = ScaffoldMessenger.of(context);
    final photosWord = report.totalImages == 1 ? 'photo' : 'photos';
    final detail = report.failures.isEmpty
        ? 'Some photos could not be uploaded.'
        : report.failures.first;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Listing published, but ${report.failedCount} of '
          '${report.totalImages} $photosWord failed: $detail',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockItemDetailsProvider(widget.stockId));

    return stockAsync.when(
      loading: () => const LoadingStateWidget(
        message: 'Loading stock details...',
      ),
      error: (e, st) => ErrorStateWidget(
        title: 'Unable to Load Stock',
        message: 'Could not load the selected stock. Please go back and '
            'choose another item.',
        retryLabel: 'Retry',
        onRetry: () => ref.invalidate(stockItemDetailsProvider(widget.stockId)),
        detailedError: e.toString(),
      ),
      data: (stock) {
        if (stock == null) {
          return const ErrorStateWidget(
            title: 'Stock Not Found',
            message: 'The selected stock is no longer available.',
          );
        }
        return _buildForm(stock);
      },
    );
  }

  Widget _buildForm(StockItem stock) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Read-only stock summary ──
          _StockSummaryCard(stock: stock),
          const SizedBox(height: 20),

          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price Per Unit *',
              prefixText: 'KSh ',
              hintText: 'e.g. 250',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final price = double.tryParse(v);
              if (price == null) return 'Invalid number';
              if (price <= 0) return 'Price must be greater than zero';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (Optional)',
              hintText: 'e.g. Fresh Organic Tomatoes',
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe your product...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          ListingImagePickerArea(
            onImagesChanged: (images) {
              setState(() => _selectedImages = images);
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submit(stock),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.storefront, size: 18),
              label: Text(
                _isSubmitting ? 'Publishing...' : 'Publish Listing',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The listing is created from your managed stock. Quantity, '
            'product, unit and location are managed by your inventory.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// READ-ONLY STOCK SUMMARY
/// ============================================================
class _StockSummaryCard extends StatelessWidget {
  final StockItem stock;

  const _StockSummaryCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_outlined, size: 20, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Managed stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stock.availableQuantity.toStringAsFixed(0)} ${stock.displayUnit} available',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.sell_outlined,
                label: '${stock.availableQuantity.toStringAsFixed(0)} '
                    '${stock.displayUnit} available',
              ),
              _InfoChip(
                icon: Icons.straighten_outlined,
                label: 'Unit: ${stock.displayUnit}',
              ),
              _InfoChip(
                icon: Icons.place_outlined,
                label: 'Location: ${stock.displayLocation}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

/// ============================================================
/// ERROR MAPPING
/// ============================================================

enum _PublishFailureKind {
  insufficientStock,
  unauthorizedStock,
  alreadyPublished,
  invalidPrice,
  network,
  generic,
}

class _PublishFailure implements Exception {
  final _PublishFailureKind kind;
  final String message;
  const _PublishFailure({required this.kind, required this.message});
}

class _PublishFailureDescription {
  final String title;
  final String message;
  final Color color;
  const _PublishFailureDescription({
    required this.title,
    required this.message,
    required this.color,
  });
}

_PublishFailureDescription _describeFailure(Object e) {
  if (e is _PublishFailure) {
    switch (e.kind) {
      case _PublishFailureKind.insufficientStock:
        return const _PublishFailureDescription(
          title: 'Insufficient Stock',
          message: 'This stock has no available quantity to list. '
              'Add inventory before publishing.',
          color: Colors.orange,
        );
      case _PublishFailureKind.unauthorizedStock:
        return const _PublishFailureDescription(
          title: 'Unauthorized Stock',
          message: 'You do not have permission to list this stock.',
          color: Colors.red,
        );
      case _PublishFailureKind.alreadyPublished:
        return const _PublishFailureDescription(
          title: 'Already Published',
          message: 'This stock already has an active listing.',
          color: Colors.orange,
        );
      case _PublishFailureKind.invalidPrice:
        return const _PublishFailureDescription(
          title: 'Invalid Price',
          message: 'Enter a price greater than zero.',
          color: Colors.red,
        );
      case _PublishFailureKind.network:
        return const _PublishFailureDescription(
          title: 'Network / RPC Failure',
          message: 'Could not reach the server. Check your connection and '
              'try again.',
          color: Colors.red,
        );
      case _PublishFailureKind.generic:
        return _PublishFailureDescription(
          title: 'Publishing Failed',
          message: e.message,
          color: Colors.red,
        );
    }
  }

  if (e is PostgrestException) {
    final message = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();

    // Unique constraint violation (stock already listed).
    if (e.code == '23505') {
      return const _PublishFailureDescription(
        title: 'Already Published',
        message: 'This stock already has an active listing.',
        color: Colors.orange,
      );
    }

    // RLS / permission denial (stock not owned by the user).
    if (e.code == '42501' || message.contains('permission') ||
        message.contains('denied') || message.contains('authorized') ||
        message.contains('row-level') || message.contains('policy') ||
        details.contains('permission') || details.contains('denied')) {
      return const _PublishFailureDescription(
        title: 'Unauthorized Stock',
        message: 'You do not have permission to list this stock.',
        color: Colors.red,
      );
    }

    // Stock availability errors surfaced by the RPC.
    if (message.contains('insufficient') ||
        message.contains('not enough') ||
        message.contains('unavailable') ||
        message.contains('out of stock') ||
        details.contains('insufficient') || details.contains('quantity')) {
      return const _PublishFailureDescription(
        title: 'Insufficient Stock',
        message: 'This stock has no available quantity to list. '
            'Add inventory before publishing.',
        color: Colors.orange,
      );
    }

    // Price validation errors surfaced by the RPC.
    if (message.contains('price') ||
        message.contains('must be greater') ||
        message.contains('greater than 0') || message.contains('positive') ||
        details.contains('price')) {
      return const _PublishFailureDescription(
        title: 'Invalid Price',
        message: 'Enter a price greater than zero.',
        color: Colors.red,
      );
    }

    // Unhappy RPC that did not map to a known category.
    return _PublishFailureDescription(
      title: 'Publishing Failed',
      message: e.message,
      color: Colors.red,
    );
  }

  // Network / transport failures (no DB error payload available).
  if (e is http.ClientException) {
    return const _PublishFailureDescription(
      title: 'Network / RPC Failure',
      message: 'Could not reach the server. Check your connection and '
          'try again.',
      color: Colors.red,
    );
  }

  final text = e.toString().toLowerCase();
  if (text.contains('socket') || text.contains('timeout') ||
      text.contains('connection') || text.contains('network') ||
      text.contains('handshake') || text.contains('failed host') ||
      text.contains('client exception')) {
    return const _PublishFailureDescription(
      title: 'Network / RPC Failure',
      message: 'Could not reach the server. Check your connection and '
          'try again.',
      color: Colors.red,
    );
  }

  return _PublishFailureDescription(
    title: 'Publishing Failed',
    message: e.toString(),
    color: Colors.red,
  );
}
