import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';

import 'listing_image_picker_area.dart';

/// ============================================================
/// CREATE LISTING FORM (STANDALONE — NO MANAGED STOCK REQUIRED)
/// ============================================================
///
/// Unified farmer-side listing form. A standalone listing is created without
/// a `commerce.stock_registry` reference (`stock_id = null`) so a farmer can
/// offer farm produce OR goods sourced elsewhere without maintaining formal
/// inventory.
///
/// Collects (schema-supported fields):
///   - product category (core.item_variants) — prefilled when context allows
///   - title
///   - description (the seller describes the exact product + quantity offered)
///   - price per unit (KES)
///   - unit (core.units)
///   - optional photographs (hardened `upload_media` flow)
///
/// Location is prefilled from the active farm/entity context and is never
/// entered by the seller. entity_id comes from the active context and is
/// validated server-side.
/// ============================================================
class CreateListingFormWidget extends ConsumerStatefulWidget {
  final String? initialVariantId;
  final String? initialTitle;
  final String? initialContextLabel;
  final String? initialLocationId;
  final String? initialLocationName;

  const CreateListingFormWidget({
    super.key,
    this.initialVariantId,
    this.initialTitle,
    this.initialContextLabel,
    this.initialLocationId,
    this.initialLocationName,
  });

  @override
  ConsumerState<CreateListingFormWidget> createState() =>
      _CreateListingFormWidgetState();
}

class _CreateListingFormWidgetState
    extends ConsumerState<CreateListingFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  List<SelectedListingImage> _selectedImages = [];
  String? _selectedVariantId;
  String? _selectedUnitId;
  bool _isSubmitting = false;

  bool _loadingRefs = true;
  String? _loadError;
  List<({String id, String itemName, String variantName})> _variants = [];
  List<({String id, String name})> _units = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty) {
      _titleController.text = widget.initialTitle!.trim();
    }
    Future.microtask(_loadReferences);
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingRefs = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(farmRepositoryProvider);
      final variants = await repo.getVariants();
      final units = await repo.getUnits();
      if (!mounted) return;
      setState(() {
        _variants = variants;
        _units = units;
        _selectedVariantId = widget.initialVariantId != null &&
                variants.any((v) => v.id == widget.initialVariantId)
            ? widget.initialVariantId
            : null;
        _loadingRefs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingRefs = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final locationId = widget.initialLocationId;
    if (locationId == null || locationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A location is required before listing. Your entity has no '
            'location configured.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final variantId = _selectedVariantId;
    if (variantId == null || variantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product category.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final price = double.parse(_priceController.text.trim());
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      final notifier = ref.read(marketplaceProvider.notifier);
      await notifier.publishStandaloneListing(
        title: title,
        pricePerUnit: price,
        variantId: variantId,
        unitId: _selectedUnitId,
        locationId: locationId,
        description: description.isEmpty ? null : description,
        images: _selectedImages,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing published successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not publish listing: ${_friendly(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendly(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('permission') ||
        t.contains('denied') ||
        t.contains('authorized') ||
        t.contains('row-level')) {
      return 'You do not have permission to list for this entity.';
    }
    if (t.contains('location')) {
      return 'A valid location is required for this listing.';
    }
    final cleaned = e.toString().startsWith('Exception: ')
        ? e.toString().substring('Exception: '.length)
        : e.toString();
    return cleaned.isEmpty ? 'please try again' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRefs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load product categories: $_loadError',
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadReferences,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.initialContextLabel != null &&
              widget.initialContextLabel!.isNotEmpty) ...[
            _ContextBanner(label: widget.initialContextLabel!),
            const SizedBox(height: 20),
          ],

          // ── Product category ──
          DropdownButtonFormField<String>(
            value: _selectedVariantId,
            decoration: InputDecoration(
              labelText: 'Product category *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            hint: const Text('Select what you are selling'),
            items: _variants
                .map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        v.itemName.isEmpty
                            ? v.variantName
                            : '${v.itemName} — ${v.variantName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedVariantId = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Fresh Organic Tomatoes',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'Describe your product and the quantity offered (e.g. '
                  '5 bags of maize).',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price per unit *',
                    prefixText: 'KSh ',
                    hintText: 'e.g. 250',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final p = double.tryParse(v);
                    if (p == null) return 'Invalid';
                    if (p <= 0) return '> 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedUnitId,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  hint: const Text('Unit'),
                  items: _units
                      .map((u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedUnitId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListingImagePickerArea(
            onImagesChanged: (images) =>
                setState(() => _selectedImages = images),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
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
              label: Text(_isSubmitting ? 'Publishing...' : 'Publish Listing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
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

class _ContextBanner extends StatelessWidget {
  final String label;

  const _ContextBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.agriculture, size: 18, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
