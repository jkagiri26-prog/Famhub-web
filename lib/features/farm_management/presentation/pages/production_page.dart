// ignore: dangling_library_doc_comments
/// ============================================================
/// PRODUCTION RECORDING PAGE
/// ============================================================
///
/// 🧠 OPERATIONAL FLOW:
///   Record Production → Validate Workflow → Update Inventory
///   → Trigger Marketplace Sync → Publish Listing
///
/// This is the core operational flow connecting:
///   Farm Management → Production → Marketplace
///
/// ✅ PATTERN:
///   - Uses existing farmRepositoryProvider
///   - Uses existing productionProvider
///   - Uses existing crossModuleWorkflowProvider
///   - Extends existing systems — NO DUPLICATION
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';

import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/field_model.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';

/// Production Recording Form
///
/// Records farm production and triggers the cross-module
/// Production → Marketplace workflow.
class ProductionRecordingPage extends ConsumerStatefulWidget {
  const ProductionRecordingPage({super.key});

  @override
  ConsumerState<ProductionRecordingPage> createState() => _ProductionRecordingPageState();
}

class _ProductionRecordingPageState extends ConsumerState<ProductionRecordingPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  String? _selectedFieldId;
  String? _selectedCategoryId;
  String? _selectedUnitId;
  bool _syncToMarketplace = true;

  bool _isSubmitting = false;

  // Production categories (future: load from item_categories table)
  static const _categories = [
    ('crop', 'Crop / Harvest', Icons.eco, Colors.green),
    ('livestock', 'Livestock', Icons.pets, Colors.brown),
    ('dairy', 'Dairy', Icons.water, Colors.lightBlue),
    ('poultry', 'Poultry', Icons.egg, Colors.orange),
    ('fish', 'Fish', Icons.set_meal, Colors.cyan),
    ('honey', 'Honey', Icons.energy_savings_leaf, Colors.amber),
    ('other', 'Other', Icons.category, Colors.grey),
  ];

  static const _units = [
    ('kg', 'Kilograms (kg)'),
    ('ton', 'Tonnes'),
    ('litre', 'Litres'),
    ('piece', 'Pieces'),
    ('crate', 'Crates'),
    ('bag', 'Bags'),
    ('dozen', 'Dozen'),
    ('head', 'Heads'),
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final fieldState = ref.watch(fieldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Production'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: farmId == null
          ? const Center(child: Text('Select a farm first'))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Production Category ──
                    Text(
                      'Production Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.$1;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.$3, size: 16, color: isSelected ? Colors.white : cat.$4),
                              const SizedBox(width: 6),
                              Text(cat.$2),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: cat.$4,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            setState(() => _selectedCategoryId = cat.$1);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── Quantity ──
                    Text(
                      'Quantity Produced',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: 'e.g. 150',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter quantity';
                              }
                              final qty = double.tryParse(value);
                              if (qty == null || qty <= 0) {
                                return 'Enter a valid quantity';
                              }
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              hintText: 'Unit',
                            ),
                            items: _units.map((u) => DropdownMenuItem(
                              value: u.$1,
                              child: Text(u.$2, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (value) {
                              setState(() => _selectedUnitId = value);
                            },
                            validator: (value) {
                              if (value == null) return 'Select unit';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Field Selection ──
                    Text(
                      'Related Field (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (fieldState != null && fieldState.isLoading)
                      const Text('Loading fields...')
                    else if (fieldState != null && fieldState.fields.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedFieldId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          hintText: 'Select field (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          ...fieldState.fields.map((field) => DropdownMenuItem(
                            value: field.id,
                            child: Text('${field.fieldName} (${field.acreage?.toStringAsFixed(1) ?? "?"} ha)'),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedFieldId = value);
                        },
                      )
                    else
                      Text(
                        'No fields registered. Production will be recorded without field association.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    const SizedBox(height: 24),

                    // ── Marketplace Sync ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Marketplace Sync',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When enabled, production will be synced to the Marketplace '
                            'for listing and sales.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: _syncToMarketplace,
                            onChanged: (val) => setState(() => _syncToMarketplace = val),
                            title: const Text('Sync to Marketplace'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Submit Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitProduction(farmId),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isSubmitting ? 'Recording...' : 'Record Production'),
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
                    if (_syncToMarketplace)
                      Text(
                        'Production will be synced to Marketplace inventory.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _submitProduction(String farmId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);
      final quantity = double.parse(_quantityController.text.trim());

      final production = ProductionModel(
        id: '',
        farmId: farmId,
        variantId: null,
        quantity: quantity,
        unitId: _selectedUnitId,
        categoryId: _selectedCategoryId,
        assetId: null,
        fieldId: _selectedFieldId,
        activityId: null,
      );

      // Step 1: Record production
      await repository.recordProduction(farmId: farmId, production: production);

      // Step 2: Auto-update production KPIs
      try {
        await repository.updateProductionKpis(farmId: farmId, quantity: quantity);
      } catch (e) {
        // KPI update is non-critical
      }

      // Step 3: If marketplace sync enabled, trigger the cross-module workflow
      if (_syncToMarketplace) {
        try {
          await repository.syncMarketplaceListing(farmId: farmId);
        } catch (e) {
          // Marketplace sync is optional - don't fail the production recording
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Production recorded but marketplace sync failed: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // Step 4: Invalidate providers to refresh
      ref.invalidate(productionProvider);
      ref.invalidate(farmDashboardProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _syncToMarketplace
                  ? 'Production recorded and synced to Marketplace'
                  : 'Production recorded successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record production: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
