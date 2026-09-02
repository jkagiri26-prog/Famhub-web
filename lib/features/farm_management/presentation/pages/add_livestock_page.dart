/// ============================================================
/// ADD LIVESTOCK PAGE — Contextual Form
/// ============================================================
///
/// 🏗️ HIERARCHY RULE:
///   Add Livestock — ONLY accessible when a Field/Block is selected.
///   Automatically receives farmId + fieldId from hierarchy context.
///   User never selects the parent farm or field — pre-filled.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

/// Add Livestock form. Requires a Field/Block to be selected in hierarchy.
///
/// farmId and fieldId are automatically read from hierarchy — user does NOT
/// pick them. This enforces: "you must be IN a field to add livestock."
///
/// Livestock are farm_management.assets (asset_type='livestock') created
/// from a selected core.item_variants (the species/breed kind).
class AddLivestockPage extends ConsumerStatefulWidget {
  const AddLivestockPage({super.key});

  @override
  ConsumerState<AddLivestockPage> createState() => _AddLivestockPageState();
}

class _AddLivestockPageState extends ConsumerState<AddLivestockPage> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedItemId;
  String? _selectedVariantId;
  bool _isSubmitting = false;
  bool _loadingCategories = true;
  bool _loadingItems = false;
  bool _loadingVariants = false;
  String? _taxonomyError;
  List<({String id, String name})> _categories = [];
  List<({String id, String categoryId, String name})> _items = [];
  List<({String id, String itemName, String variantName})> _variants = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCategories);
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _taxonomyError = null;
    });
    try {
      final categories = await ref.read(farmRepositoryProvider).getCategoriesForAssetType(assetType: 'livestock');
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = null;
        _selectedItemId = null;
        _selectedVariantId = null;
        _items = [];
        _variants = [];
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _taxonomyError = e.toString();
        _loadingCategories = false;
      });
    }
  }

  Future<void> _loadItemsForCategory(String categoryId) async {
    setState(() {
      _loadingItems = true;
      _taxonomyError = null;
      _selectedItemId = null;
      _selectedVariantId = null;
      _variants = [];
      _items = [];
    });
    try {
      final items = await ref.read(farmRepositoryProvider).getItemsForCategory(categoryId: categoryId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _taxonomyError = e.toString();
        _loadingItems = false;
      });
    }
  }

  Future<void> _loadVariantsForItem(String itemId) async {
    setState(() {
      _loadingVariants = true;
      _taxonomyError = null;
      _selectedVariantId = null;
      _variants = [];
    });
    try {
      final variants = await ref.read(farmRepositoryProvider).getVariantsForItem(itemId: itemId);
      if (!mounted) return;
      setState(() {
        _variants = variants;
        _loadingVariants = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _taxonomyError = e.toString();
        _loadingVariants = false;
      });
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(hierarchyProvider);
    final farmContext = ref.watch(farmContextProvider);
    final farmId = farmContext.farmId;
    final fieldId = hierarchy.fieldId;
    final fieldName = hierarchy.field?.fieldName ?? 'Field';
    final farmName = farmContext.farm?.farmName ?? 'Farm';

    // 🚫 BLOCK: No field selected
    if (farmId == null || fieldId == null) {
      return const ShellPageContent(
        title: 'Add Livestock',
        subtitle: 'Select a field first',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('Select a Field/Block first to add livestock.',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return ShellPageContent(
      title: 'Add Livestock',
      subtitle: 'Adding to $fieldName ($farmName)',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Context banner ──
              _buildContextBanner(farmName, fieldName),
              const SizedBox(height: 24),

              // ── Taxonomy selection (authoritative: core.categories → core.items → core.item_variants) ──
              Text('Livestock taxonomy',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Choose the livestock category, item, and breed/species to add as a livestock '
                'asset to $fieldName.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (_loadingCategories)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_taxonomyError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load livestock taxonomy: $_taxonomyError',
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    hintText: 'Select livestock category',
                  ),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedItemId = null;
                      _selectedVariantId = null;
                      _variants = [];
                    });
                    _loadItemsForCategory(value);
                  },
                  validator: (value) => (value == null) ? 'Select a livestock category' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedItemId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    hintText: 'Select livestock item',
                  ),
                  items: _items.map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: _selectedCategoryId == null
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedItemId = value;
                            _selectedVariantId = null;
                            _variants = [];
                          });
                          _loadVariantsForItem(value);
                        },
                  validator: (value) => (_selectedCategoryId == null || value == null) ? 'Select a livestock item' : null,
                ),
                const SizedBox(height: 16),
                if (_loadingItems || _loadingVariants)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedItemId),
                    value: _selectedVariantId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintText: _variants.isEmpty
                          ? 'No livestock types available'
                          : 'Select livestock type',
                    ),
                    items: _variants.map((v) => DropdownMenuItem(
                      value: v.id,
                      child: Text(
                        v.itemName.isEmpty ? v.variantName : '${v.itemName} — ${v.variantName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    )).toList(),
                    onChanged: _selectedItemId == null || _variants.isEmpty
                        ? null
                        : (value) => setState(() => _selectedVariantId = value),
                    validator: (value) => (_selectedItemId == null || value == null) ? 'Select a livestock type' : null,
                  ),
              ],
              const SizedBox(height: 20),

              // ── Count ──
              Text('Animal Count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. 50',
                  suffixText: 'head',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter animal count';
                  final count = int.tryParse(v);
                  if (count == null || count <= 0) return 'Enter a valid count';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Notes ──
              Text('Notes (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Health status, feeding plan, etc.',
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isSubmitting ? 'Adding...' : 'Add Livestock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextBanner(String farmName, String fieldName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.pets, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adding livestock to: $fieldName › $farmName',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ── Guest mode: show sign-up prompt instead of saving ──
    final shouldProceed = await showProtectedActionPrompt(
      context,
      ref,
      action: 'add livestock',
    );
    if (!shouldProceed) return;

    final farmId = ref.read(farmContextProvider).farmId;
    final fieldId = ref.read(hierarchyProvider).fieldId;
    if (farmId == null || fieldId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);
      final variant = _variants.firstWhere(
        (v) => v.id == _selectedVariantId,
        orElse: () => (id: '', itemName: '', variantName: ''),
      );
      final livestock = LivestockEntity(
        id: '',
        farmId: farmId,
        fieldId: fieldId,
        variantId: _selectedVariantId,
        species: variant.itemName.isEmpty
            ? variant.variantName
            : variant.itemName,
        breed: variant.variantName.isEmpty ? null : variant.variantName,
        count: int.parse(_countController.text.trim()),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await repository.createLivestock(farmId: farmId, livestock: livestock);
      ref.invalidate(livestockProvider);
      ref.invalidate(livestockByFieldProvider);
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (!mounted) return;
      final fieldLabel = ref.read(hierarchyProvider).field?.fieldName ?? 'field';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${livestock.species} added to $fieldLabel'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
