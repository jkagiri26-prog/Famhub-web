// ignore: dangling_library_doc_comments
/// ============================================================
/// PRODUCTION RECORDING PAGE
/// ============================================================
///
/// 🧠 OPERATIONAL FLOW:
///   Record Production → Backend trigger creates/updates Commerce stock
///   (trg_sync_production_to_stock → sync_production_to_stock →
///   stock_movements → apply_stock_movement → commerce.stock_registry)
///   → the seller explicitly publishes via "Sell on Marketplace".
///
/// This is the core operational flow connecting:
///   Farm Management → Production → Marketplace
///
/// ✅ PATTERN:
///   - Uses existing farmRepositoryProvider
///   - Uses existing productionProvider
///   - Extends existing systems — NO DUPLICATION
///
/// ✅ BACKEND CONTRACT (confirmed):
///   The production sync trigger requires:
///     - NEW.quantity > 0
///     - NEW.output_commodity_id IS NOT NULL (→ core.commodities.id)
///     - NEW.entity_id IS NOT NULL (derived server-side via core.auth_user_id())
///   The form therefore collects the output commodity and unit from the
///   existing taxonomy (core.commodities / core.units) and NEVER sends
///   non-UUID labels.
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';

import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/stock_selection_page.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

/// Production Recording Form
///
/// Production is created EXPLICITLY from an existing activity via
/// `farm_management.create_production_record(p_production_data jsonb)`.
/// The backend derives farm/field/asset/entity context from the
/// activity → asset chain. Publishing to Marketplace is always explicit.
class ProductionRecordingPage extends ConsumerStatefulWidget {
  /// Optional pre-selected activity to record production against.
  final String? initialActivityId;

  const ProductionRecordingPage({super.key, this.initialActivityId});

  @override
  ConsumerState<ProductionRecordingPage> createState() => _ProductionRecordingPageState();
}

class _ProductionRecordingPageState extends ConsumerState<ProductionRecordingPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCommodityId;
  String? _selectedUnitId;
  String? _selectedFieldId;
  bool _isSubmitting = false;

  // Reference data (existing taxonomy: core.commodities / core.units)
  bool _loadingReferences = true;
  String? _loadError;
  List<({String id, String name, String category})> _commodities = [];
  List<({String id, String name})> _units = [];

  // Activities to produce from (production requires an existing activity).
  bool _loadingActivities = true;
  String? _activitiesError;
  List<ActivityModel> _activities = [];
  String? _selectedActivityId;

  // Production categories are used as a browsing FILTER over the existing
  // core.commodities table (commodity.category). No new mapping is invented.
  static const _categories = [
    ('crop', 'Crop / Harvest', Icons.eco, Colors.green),
    ('livestock', 'Livestock', Icons.pets, Colors.brown),
    ('dairy', 'Dairy', Icons.water, Colors.lightBlue),
    ('poultry', 'Poultry', Icons.egg, Colors.orange),
    ('fish', 'Fish', Icons.set_meal, Colors.cyan),
    ('honey', 'Honey', Icons.energy_savings_leaf, Colors.amber),
    ('other', 'Other', Icons.category, Colors.grey),
  ];

  static const _specificCategoryKeys = ['crop', 'livestock', 'dairy', 'poultry', 'fish', 'honey'];

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    // Prefill the field from the current hierarchy context when available.
    final hierarchy = ref.read(hierarchyProvider);
    if (hierarchy.hasField) {
      _selectedFieldId = hierarchy.fieldId;
    }
    await _loadActivities();
    await _loadReferences();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loadingActivities = true;
      _activitiesError = null;
    });
    try {
      final repository = ref.read(farmRepositoryProvider);
      final farmId = ref.read(farmContextProvider).farmId;
      final hierarchy = ref.read(hierarchyProvider);
      if (farmId == null) {
        _activities = const [];
      } else {
        var activities = await repository.getActivities(farmId: farmId);
        // Production derives context from the activity → asset chain. When a
        // crop/livestock asset is selected in the hierarchy, prefer its
        // activities.
        final assetId = hierarchy.cropOrLivestockId;
        if (assetId != null) {
          final scoped = activities.where((a) => a.assetId == assetId).toList();
          if (scoped.isNotEmpty) activities = scoped;
        }
        _activities = activities;
      }
      _selectedActivityId = _activities.any((a) => a.id == widget.initialActivityId)
          ? widget.initialActivityId
          : null;
      if (!mounted) return;
      setState(() {
        _loadingActivities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activitiesError = e.toString();
        _loadingActivities = false;
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loadingReferences = true;
      _loadError = null;
    });
    try {
      final repository = ref.read(farmRepositoryProvider);
      final commodities = await repository.getCommodities();
      final units = await repository.getUnits();
      if (!mounted) return;
      setState(() {
        _commodities = commodities;
        _units = units;
        _loadingReferences = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingReferences = false;
      });
    }
  }

  /// Commodities matching the selected category filter.
  ///
  /// Falls back to showing ALL commodities when a filter matches nothing,
  /// so the farmer is never blocked by taxonomy label drift.
  List<({String id, String name, String category})> get _filteredCommodities {
    final key = _selectedCategoryId;
    if (key == null) return _commodities;
    if (key == 'other') {
      final other = _commodities.where((c) {
        final cat = c.category.toLowerCase();
        return _specificCategoryKeys.every((k) => !cat.contains(k));
      }).toList();
      return other.isEmpty ? _commodities : other;
    }
    final matched = _commodities
        .where((c) => c.category.toLowerCase().contains(key.toLowerCase()))
        .toList();
    return matched.isEmpty ? _commodities : matched;
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final fieldState = ref.watch(fieldsProvider);

        return ShellPageContent(
      title: 'Record Production',
      actions: [
        // Explicit sell action — production never auto-publishes.
        IconButton(
          onPressed: () => _navigateToSellOnMarketplace(context),
          icon: const Icon(Icons.storefront_outlined),
          tooltip: 'Sell on Marketplace',
        ),
      ],
      child: farmId == null
          ? const Center(child: Text('Select a farm first'))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Activity (production is recorded from an activity) ──
                    Text(
                      'From Activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Production is recorded against an existing activity. '
                      'Farm, field and asset context are derived from it.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    _buildActivityPicker(),
                    const SizedBox(height: 24),

                    // ── Production Category (filter for commodity picker) ──
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
                            setState(() {
                              _selectedCategoryId = selected ? cat.$1 : null;
                              _selectedCommodityId = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── Output Commodity (required by the backend trigger) ──
                    Text(
                      'Output Commodity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Determines the Commerce stock that will be created for this production.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    _buildCommodityPicker(),
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
                              value: u.id,
                              child: Text(u.name, style: const TextStyle(fontSize: 13)),
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
                    if (fieldState.isLoading)
                      const Text('Loading fields...')
                    else if (fieldState.fields.isNotEmpty)
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

                    // ── Marketplace Note ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.store, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Marketplace stock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recording production automatically creates/updates your '
                                  'Commerce stock. Use "Sell on Marketplace" to publish a listing '
                                  '— production is never published automatically.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
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
                        onPressed: (_isSubmitting || _activities.isEmpty || _commodities.isEmpty || _loadError != null)
                            ? null
                            : () => _submitProduction(farmId),
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActivityPicker() {
    if (_loadingActivities) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_activitiesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load activities: $_activitiesError',
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadActivities,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    if (_activities.isEmpty) {
      return Text(
        'No activities yet. Record an activity on a crop or livestock first '
        '— production must be created from an activity.',
        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedActivityId,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: 'Select activity',
      ),
      items: _activities.map((a) => DropdownMenuItem(
        value: a.id,
        child: Text(
          '${a.activityTypeId} · '
          '${a.performedAt.day}/${a.performedAt.month}/${a.performedAt.year}',
          style: const TextStyle(fontSize: 13),
        ),
      )).toList(),
      onChanged: (value) {
        setState(() => _selectedActivityId = value);
      },
      validator: (value) {
        if (value == null) return 'Select the activity that produced this output';
        return null;
      },
    );
  }

  Widget _buildCommodityPicker() {
    if (_loadingReferences) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load commodities: $_loadError',
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
    if (_commodities.isEmpty) {
      return Text(
        'No commodities available in core.commodities. '
        'Production cannot create Commerce stock without an output commodity.',
        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
      );
    }

    final filtered = _filteredCommodities;
    return DropdownButtonFormField<String>(
      value: filtered.any((c) => c.id == _selectedCommodityId)
          ? _selectedCommodityId
          : null,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: 'Select commodity',
      ),
      items: filtered.map((c) => DropdownMenuItem(
        value: c.id,
        child: Text(
          c.category.trim().isEmpty
              ? c.name
              : '${c.name} (${c.category})',
          style: const TextStyle(fontSize: 13),
        ),
      )).toList(),
      onChanged: (value) {
        setState(() => _selectedCommodityId = value);
      },
      validator: (value) {
        if (value == null) return 'Select an output commodity';
        return null;
      },
    );
  }

  void _navigateToSellOnMarketplace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StockSelectionPage()),
    );
  }

  Future<void> _submitProduction(String farmId) async {
      if (!_formKey.currentState!.validate()) return;

      // ── Guest mode: show sign-up prompt instead of saving ──
      final shouldProceed = await showProtectedActionPrompt(
        context,
        ref,
        action: 'record production',
      );
      if (!shouldProceed) return;

      setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);
      final quantity = double.parse(_quantityController.text.trim());

      final production = ProductionEntity(
        id: '',
        activityId: _selectedActivityId,
        variantId: null,
        outputCommodityId: _selectedCommodityId,
        quantity: quantity,
        unitId: _selectedUnitId,
        categoryId: null,
        assetId: null,
        fieldId: null,
        sourceType: 'activity',
      );

      // Step 1: Record production via create_production_record. The backend
      // derives farm/field/asset/entity from the activity → asset chain, then
      // the production → Commerce stock pipeline creates/updates stock.
      await repository.recordProduction(farmId: farmId, production: production);

      // Step 2: Auto-update production KPIs
      try {
        await repository.updateProductionKpis(farmId: farmId, quantity: quantity);
      } catch (e) {
        // KPI update is non-critical
      }

      // Step 3: Invalidate providers to refresh
      ref.invalidate(productionProvider);
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Production recorded. Stock was created — use '
              '"Sell on Marketplace" to publish a listing.',
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
