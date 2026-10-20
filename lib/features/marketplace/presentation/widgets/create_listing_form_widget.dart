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
///   - description
///   - price per unit (KES)
///   - quantity offered (required, positive) + unit (required)
///   - optional photographs (hardened `upload_media` flow)
///
/// Location is prefilled from the active farm/entity context when available;
/// otherwise the seller picks an existing canonical `core.locations` entry.
/// entity_id comes from the active context and is validated server-side.
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
  final _quantityController = TextEditingController();

  List<SelectedListingImage> _selectedImages = [];
  String? _selectedVariantId;
  String? _selectedUnitId;
  String? _selectedLocationId;
  String? _selectedLocationName;
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
    if (widget.initialLocationId != null &&
        widget.initialLocationId!.trim().isNotEmpty) {
      _selectedLocationId = widget.initialLocationId!.trim();
      _selectedLocationName = widget.initialLocationName;
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
      final marketRepo = ref.read(marketplaceRepositoryProvider);
      final variants = await repo.getVariants();
      final units = await repo.getUnits();

      // Resolve the prefilled location's display name when the caller only
      // supplied the id (canonical `core.locations` lookup — never a guess).
      String? locationName = widget.initialLocationName;
      final prefilledId = _selectedLocationId;
      if ((locationName == null || locationName.trim().isEmpty) &&
          prefilledId != null) {
        try {
          final names = await marketRepo.fetchLocationNames({prefilledId});
          locationName = names[prefilledId];
        } catch (_) {
          // Name resolution is display-only; fall back to the picker label.
        }
      }

      if (!mounted) return;
      setState(() {
        _variants = variants;
        _units = units;
        _selectedLocationName = locationName;
        _selectedVariantId =
            widget.initialVariantId != null &&
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
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final locationId = _selectedLocationId;
    if (locationId == null || locationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a location for this listing. Your entity has no '
            'location configured, so pick one from the list.',
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

    final unitId = _selectedUnitId;
    if (unitId == null || unitId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a unit (e.g. kg, bag).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final price = double.parse(_priceController.text.trim());
      final quantityOffered = double.parse(_quantityController.text.trim());
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      final notifier = ref.read(marketplaceProvider.notifier);
      await notifier.publishStandaloneListing(
        title: title,
        pricePerUnit: price,
        variantId: variantId,
        unitId: unitId,
        quantityOffered: quantityOffered,
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

  /// The selected unit's name, shown as the quantity field suffix.
  String _selectedUnitSuffix() {
    final id = _selectedUnitId;
    if (id == null) return '';
    for (final u in _units) {
      if (u.id == id) return '/ ${u.name}';
    }
    return '';
  }

  /// Location input: read-only prefilled value from the entity context, or a
  /// canonical `core.locations` search picker when no context location exists.
  Widget _buildLocationField() {
    final prefilled =
        _selectedLocationId != null &&
        widget.initialLocationId != null &&
        _selectedLocationId == widget.initialLocationId;

    if (prefilled) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Location',
          prefixIcon: Icon(Icons.place_outlined, size: 20),
          helperText: 'From your farm location',
        ),
        child: Text(
          (_selectedLocationName != null && _selectedLocationName!.isNotEmpty)
              ? _selectedLocationName!
              : 'Farm location',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }

    return _LocationPickerField(
      selectedLocationId: _selectedLocationId,
      selectedLocationName: _selectedLocationName,
      onSelected: (id, name) => setState(() {
        _selectedLocationId = id;
        _selectedLocationName = name;
      }),
    );
  }

  String _friendly(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('permission') ||
        t.contains('denied') ||
        t.contains('authorized') ||
        t.contains('row-level')) {
      return 'You do not have permission to list for this entity.';
    }
    if (t.contains('quantity')) {
      return 'Quantity offered must be greater than zero.';
    }
    if (t.contains('unit')) {
      return 'A valid unit is required for this listing.';
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
              hintText: 'Describe your product (e.g. sun-dried, sorted).',
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
                    labelText: 'Unit *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  hint: const Text('Unit'),
                  items: _units
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedUnitId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity offered *',
              hintText: 'e.g. 120',
              suffixText: _selectedUnitSuffix(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final q = double.tryParse(v);
              if (q == null) return 'Invalid';
              if (q <= 0) return '> 0';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Location ──
          _buildLocationField(),
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

/// ============================================================
/// LOCATION PICKER FIELD (CANONICAL `core.locations` ONLY)
/// ============================================================
///
/// Seller-side fallback used when the active entity context has no location:
/// search existing canonical `core.locations` entries and select one.
/// Never creates a location and never invents an id.
class _LocationPickerField extends ConsumerStatefulWidget {
  final String? selectedLocationId;
  final String? selectedLocationName;
  final void Function(String id, String name) onSelected;

  const _LocationPickerField({
    this.selectedLocationId,
    this.selectedLocationName,
    required this.onSelected,
  });

  @override
  ConsumerState<_LocationPickerField> createState() =>
      _LocationPickerFieldState();
}

class _LocationPickerFieldState extends ConsumerState<_LocationPickerField> {
  final _searchController = TextEditingController();
  late bool _editing;

  @override
  void initState() {
    super.initState();
    final selected = widget.selectedLocationId;
    _editing = selected == null || selected.isEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasSelection =>
      widget.selectedLocationId != null &&
      widget.selectedLocationId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_editing && _hasSelection) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Location *',
          prefixIcon: const Icon(Icons.place_outlined, size: 20),
          helperText: 'Pick an existing location to change',
          suffixIcon: TextButton(
            onPressed: () => setState(() => _editing = true),
            child: const Text('Change'),
          ),
        ),
        child: Text(
          (widget.selectedLocationName?.isNotEmpty ?? false)
              ? widget.selectedLocationName!
              : 'Selected location',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }

    final query = _searchController.text.trim();
    final showResults = query.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Location *',
            prefixIcon: Icon(Icons.place_outlined, size: 20),
            hintText: 'Search your area (e.g. Nakuru)',
            helperText: 'Select an existing location',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (showResults) ...[
          const SizedBox(height: 6),
          _LocationSearchResults(
            query: query,
            onSelected: (id, name) {
              widget.onSelected(id, name);
              _searchController.clear();
              setState(() => _editing = false);
            },
          ),
        ],
        if (_hasSelection) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _editing = false;
                _searchController.clear();
              }),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel search'),
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationSearchResults extends ConsumerWidget {
  final String query;
  final void Function(String id, String name) onSelected;

  const _LocationSearchResults({required this.query, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(locationSearchProvider(query));

    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              'Could not search locations.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(locationSearchProvider(query)),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'No location found for "$query".',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final loc = results[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined, size: 18),
                title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                onTap: () => onSelected(loc.id, loc.name),
              );
            },
          ),
        );
      },
    );
  }
}
