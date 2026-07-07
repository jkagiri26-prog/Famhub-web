import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';

class ListingFormWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const ListingFormWidget({super.key, this.initialData});

  @override
  ConsumerState<ListingFormWidget> createState() =>
      _ListingFormWidgetState();
}

class _ListingFormWidgetState extends ConsumerState<ListingFormWidget> {
  final _formKey = GlobalKey<FormState>();

    final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitIdController = TextEditingController();    // FK to core.units
  final _locationIdController = TextEditingController(); // FK to core.locations
  final _variantIdController = TextEditingController();  // FK to core.item_variants
  final _stockIdController = TextEditingController();    // FK to commerce.stock_registry
  final _entityIdController = TextEditingController();   // FK to core.entities
  final _imageUrlsController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

        final data = widget.initialData;
    if (data != null) {
      _titleController.text = data['title']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _priceController.text = data['price_per_unit']?.toString() ?? '';
      _unitIdController.text = data['unit_id']?.toString() ?? '';
      _locationIdController.text = data['location_id']?.toString() ?? '';
      _variantIdController.text = data['variant_id']?.toString() ?? '';
      _stockIdController.text = data['stock_id']?.toString() ?? '';
      _entityIdController.text = data['entity_id']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
        _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _unitIdController.dispose();
    _locationIdController.dispose();
    _variantIdController.dispose();
    _stockIdController.dispose();
    _entityIdController.dispose();
    _imageUrlsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final rawImages = _imageUrlsController.text.trim();

      final images = rawImages.isNotEmpty
          ? rawImages
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

            final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price_per_unit': double.tryParse(_priceController.text) ?? 0,
        'unit_id': _unitIdController.text.trim().isEmpty
            ? null
            : _unitIdController.text.trim(),
        'location_id': _locationIdController.text.trim().isEmpty
            ? null
            : _locationIdController.text.trim(),
        'variant_id': _variantIdController.text.trim().isEmpty
            ? null
            : _variantIdController.text.trim(),
        'stock_id': _stockIdController.text.trim().isEmpty
            ? null
            : _stockIdController.text.trim(),
        'entity_id': _entityIdController.text.trim().isEmpty
            ? null
            : _entityIdController.text.trim(),
        'images': images,
      };

      final notifier = ref.read(marketplaceProvider.notifier);

      if (widget.initialData != null) {
        final id =
            widget.initialData!['id']?.toString().trim() ?? '';

        if (id.isEmpty) {
          throw Exception('Invalid listing ID');
        }

        await notifier.updateListing(id, payload);
      } else {
        await notifier.createListing(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialData != null
                ? 'Listing updated'
                : 'Listing created'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Product Title *',
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
              hintText: 'Describe your product...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

                    TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price Per Unit *',
              prefixText: 'KSh ',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid number';
              return null;
            },
          ),

                    const SizedBox(height: 16),

          TextFormField(
            controller: _unitIdController,
            decoration: const InputDecoration(
              labelText: 'Unit ID',
              hintText: 'UUID of core.units (e.g. kg)',
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _locationIdController,
            decoration: const InputDecoration(
              labelText: 'Location ID',
              hintText: 'UUID of core.locations',
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _variantIdController,
            decoration: const InputDecoration(
              labelText: 'Variant ID',
              hintText: 'UUID of core.item_variants',
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _stockIdController,
            decoration: const InputDecoration(
              labelText: 'Stock ID',
              hintText: 'UUID of commerce.stock_registry',
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _entityIdController,
            decoration: const InputDecoration(
              labelText: 'Entity ID (Seller)',
              hintText: 'UUID of core.entities',
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _imageUrlsController,
            decoration: const InputDecoration(
              labelText: 'Image URLs (comma separated)',
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.initialData != null
                      ? 'Update Listing'
                      : 'Publish Listing'),
            ),
          ),
        ],
      ),
    );
  }
}