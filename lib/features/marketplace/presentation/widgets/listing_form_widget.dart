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
  final _unitController = TextEditingController(text: 'kg');
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _imageUrlsController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;
    if (data != null) {
      _titleController.text = data['title']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _unitController.text = data['unit']?.toString() ?? 'kg';
      _locationController.text = data['location']?.toString() ?? '';
      _quantityController.text =
          data['available_quantity']?.toString() ?? '1';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
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
        'price': double.tryParse(_priceController.text) ?? 0,
        'unit': _unitController.text.trim(),
        'location': _locationController.text.trim(),
        'available_quantity':
            double.tryParse(_quantityController.text) ?? 1,
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

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    prefixText: 'KSh ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Available Quantity',
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
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