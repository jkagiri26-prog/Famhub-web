import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_edit_changes.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_edit_images_state.dart';
import 'package:famhub_app/features/marketplace/infrastructure/services/listing_edit_error_mapper.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/listing_edit_images_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

/// ============================================================
/// LISTING EDIT PAGE
/// ============================================================
///
/// Edits the editable metadata of an existing listing and lets the seller
/// activate / deactivate it.
///
/// Editable fields (metadata only):
///   - title
///   - description
///   - price_per_unit (numeric)
///   - currency (display-only KES — no currency picker)
///
/// NOT editable here: stock, seller/entity, variant, unit, location, images,
/// promotion, timestamps, internal ids.
///
/// Mutations go exclusively through the canonical RPCs
/// (`update_listing` / `set_listing_status`); the backend authorizes via the
/// authenticated session. This page never sends a user id, entity id or any
/// protected field.
/// ============================================================
class ListingEditPage extends ConsumerWidget {
  final String listingId;

  const ListingEditPage({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailsProvider(listingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: ResponsiveWrapper(
        child: listingAsync.when(
          loading: () =>
              const LoadingStateWidget(message: 'Loading listing...'),
          error: (e, _) => ErrorStateWidget(
            title: 'Could Not Load Listing',
            message: 'Failed to load the listing you want to edit.',
            retryLabel: 'Retry',
            onRetry: () => ref.invalidate(listingDetailsProvider(listingId)),
            detailedError: e.toString(),
          ),
          data: (listing) {
            if (listing == null) {
              return const EmptyStateWidget(
                icon: Icons.search_off,
                title: 'Listing Not Found',
                subtitle: 'The requested listing could not be found.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const ModuleHeaderWidget(
                  title: 'Edit Listing',
                  subtitle: 'Update details or listing availability',
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _ListingEditForm(
                      key: ValueKey(listing.id),
                      listing: listing,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ============================================================
/// LISTING EDIT FORM (PRIVATE)
/// ============================================================
class _ListingEditForm extends ConsumerStatefulWidget {
  final Listing listing;

  const _ListingEditForm({super.key, required this.listing});

  @override
  ConsumerState<_ListingEditForm> createState() => _ListingEditFormState();
}

class _ListingEditFormState extends ConsumerState<_ListingEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  late Listing _original;
  bool _isSaving = false;
  bool _isChangingStatus = false;

  /// Staged photo edits (additions + removals) reported by the photos section.
  /// This is the single source of truth for image dirty-state; nothing here is
  /// persisted until Save commits it through the media flow.
  ListingEditImagesState _imageDraft = const ListingEditImagesState();

  @override
  void initState() {
    super.initState();
    _original = widget.listing;
    _titleController.text = widget.listing.title;
    _descriptionController.text = widget.listing.description ?? '';
    _priceController.text = _formatPrice(widget.listing.pricePerUnit);
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onImagesStateChanged(ListingEditImagesState draft) {
    if (!mounted) return;
    setState(() => _imageDraft = draft);
  }

  static String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return price.toStringAsFixed(0);
    }
    return '$price';
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _priceController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ListingEditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the "original" baseline in sync when the parent provider delivers a
    // fresh copy (e.g. after an external refresh). Typed edits are preserved.
    if (oldWidget.listing.id == widget.listing.id &&
        oldWidget.listing.updatedAt != widget.listing.updatedAt) {
      _original = widget.listing;
      // A fresh listing copy represents a new baseline for staged photo
      // changes (e.g. media changed elsewhere); drop previously staged edits
      // rather than saving them against stale state.
      _imageDraft = const ListingEditImagesState();
    }
  }

  /// Whether the user has actually changed an editable field or staged an
  /// image add/removal.
  ///
  /// An invalid/empty price input also counts as "edited" so the form can
  /// surface validation feedback instead of silently disabling Save.
  bool get _hasEdits {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final parsedPrice = double.tryParse(priceText);

    final titleChanged = title != _original.title;
    final effectiveDescription = description.isEmpty ? null : description;
    final descriptionChanged = effectiveDescription != _original.description;
    final priceEdited =
        priceText.isNotEmpty &&
        (parsedPrice == null ||
            parsedPrice <= 0 ||
            parsedPrice != _original.pricePerUnit);
    final currencyChanged = _original.currency != 'KES';

    return titleChanged ||
        descriptionChanged ||
        priceEdited ||
        currencyChanged ||
        _imageDraft.hasChanges;
  }

  double? get _parsedPrice {
    final value = double.tryParse(_priceController.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = _parsedPrice;
    final listing = _original;
    if (price == null) return;

    final changes = ListingEditChanges.diff(
      original: listing,
      title: _titleController.text,
      description: _descriptionController.text,
      pricePerUnit: price,
      currency: 'KES',
    );

    final imageDraft = _imageDraft;
    if (changes.isEmpty && !imageDraft.hasChanges) return;

    setState(() => _isSaving = true);

    try {
      final report = await ref
          .read(marketplaceProvider.notifier)
          .saveListingEdit(
            listingId: listing.id,
            changes: changes,
            images: imageDraft,
          );

      if (!report.allSaved) {
        if (report.metadataError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(describeListingSaveError(report.metadataError!)),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Metadata saved, but some photo changes failed. Match the existing
        // publish-flow convention: report the partial result truthfully, then
        // return so the refreshed listing/media state reflects what exists.
        if (!mounted) return;
        _showPartialImageFailure(report);
        Navigator.of(context).pop(true);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeListingSaveError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPartialImageFailure(ListingEditSaveReport report) {
    final detail = report.imageFailures.isEmpty
        ? 'Some photos could not be updated.'
        : report.imageFailures.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Listing saved, but ${report.imageFailures.length} photo '
          '${report.imageFailures.length == 1 ? 'change' : 'changes'} '
          'failed: $detail',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _confirmAndChangeStatus({required bool activating}) async {
    if (_isChangingStatus) return;
    final listing = widget.listing;

    final confirmTitle = activating
        ? 'Activate listing?'
        : 'Deactivate listing?';
    final confirmBody = activating
        ? 'This listing will become active if stock is available.'
        : 'This listing will no longer appear as an active '
              'Marketplace listing.';
    final confirmLabel = activating ? 'Activate' : 'Deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: activating
                ? null
                : TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isChangingStatus = true);

    try {
      await ref
          .read(marketplaceProvider.notifier)
          .setListingStatus(
            listingId: listing.id,
            status: activating ? ListingStatus.active : ListingStatus.inactive,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activating ? 'Listing activated.' : 'Listing deactivated.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeListingStatusError(e, activating: activating),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final saving = _isSaving || _isChangingStatus;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(listing),
          const SizedBox(height: 20),

          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Fresh Organic Tomatoes',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe your product...',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),

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
            initialValue: 'KES',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Currency',
              helperText: 'KES only',
            ),
          ),
          const SizedBox(height: 16),

          ListingEditImagesSection(
            listingId: listing.id,
            onStateChanged: _onImagesStateChanged,
          ),
          const SizedBox(height: 16),

          Text(
            'Quantity, product, unit and location are managed by your '
            'inventory and cannot be edited here.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('listing_edit_save_button'),
              onPressed: (saving || !_hasEdits) ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
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
        ],
      ),
    );
  }

  Widget _buildStatusSection(Listing listing) {
    final status = listing.status;
    if (status == ListingStatus.archived || status == ListingStatus.soldOut) {
      return const SizedBox.shrink();
    }

    final activating = status != ListingStatus.active;
    final busy = _isChangingStatus;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == ListingStatus.active
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: status == ListingStatus.active
                    ? Colors.green
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              const Text(
                'Listing Status',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: status == ListingStatus.active
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.value.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: status == ListingStatus.active
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: activating
                ? ElevatedButton.icon(
                    key: const Key('listing_status_toggle_button'),
                    onPressed: busy
                        ? null
                        : () => _confirmAndChangeStatus(activating: true),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(busy ? 'Activating...' : 'Activate listing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    key: const Key('listing_status_toggle_button'),
                    onPressed: busy
                        ? null
                        : () => _confirmAndChangeStatus(activating: false),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : const Icon(Icons.pause_circle_outline, size: 18),
                    label: Text(
                      busy ? 'Deactivating...' : 'Deactivate listing',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
