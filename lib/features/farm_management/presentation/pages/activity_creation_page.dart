import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/assets_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_live_providers.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/activity_template_selection_page.dart';

/// Activity Creation Form
///
/// Users can choose between:
/// 1. Quick Activity - Simple form with type, notes, and asset
/// 2. Guided Workflow - Multi-step dynamic form from templates
class ActivityCreationPage extends ConsumerStatefulWidget {
  const ActivityCreationPage({super.key});

  @override
  ConsumerState<ActivityCreationPage> createState() => _ActivityCreationPageState();
}

class _ActivityCreationPageState extends ConsumerState<ActivityCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController();
  String? _selectedAssetId;
  String? _selectedCommodityId;
  String? _selectedUnitId;
  String _activityTypeId = 'general';
  DateTime _performedAt = DateTime.now();
  bool _isSubmitting = false;
  bool _loadingProductionReferences = false;
  String? _productionReferencesError;
  List<({String id, String name, String category})> _commodities = [];
  List<({String id, String name})> _units = [];

  static const _activityTypes = [
    ('general', 'General Activity', Icons.event_note, Colors.blue),
    ('planting', 'Planting', Icons.eco, Colors.green),
    ('irrigation', 'Irrigation', Icons.water_drop, Colors.cyan),
    ('fertilizing', 'Fertilizing', Icons.biotech, Colors.teal),
    ('pest_control', 'Pest Control', Icons.bug_report, Colors.orange),
    ('harvesting', 'Harvesting', Icons.shopping_basket, Colors.green),
    ('maintenance', 'Maintenance', Icons.build, Colors.blueGrey),
    ('feeding', 'Feeding', Icons.restaurant, Colors.brown),
    ('milking', 'Milking', Icons.water, Colors.lightBlue),
    ('vaccination', 'Vaccination', Icons.medical_services, Colors.red),
    ('inspection', 'Inspection', Icons.visibility, Colors.purple),
    ('transport', 'Transport', Icons.local_shipping, Colors.indigo),
    ('other', 'Other', Icons.more_horiz, Colors.grey),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProductionReferences() async {
    if (_loadingProductionReferences || _commodities.isNotEmpty) return;
    setState(() {
      _loadingProductionReferences = true;
      _productionReferencesError = null;
    });
    try {
      final repository = ref.read(farmRepositoryProvider);
      final commodities = await repository.getCommodities();
      final units = await repository.getUnits();
      if (!mounted) return;
      setState(() {
        _commodities = commodities;
        _units = units;
        _loadingProductionReferences = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productionReferencesError = e.toString();
        _loadingProductionReferences = false;
      });
    }
  }

  List<({String id, String name, String category})> _commoditiesFor(
    HierarchySelectionState hierarchy,
  ) {
    final type = hierarchy.cropOrLivestockType;
    if (type == null) return _commodities;
    return _commodities
        .where((commodity) =>
            commodity.category.toLowerCase().contains(type.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final hierarchy = ref.watch(hierarchyProvider);
    final assetState = farmId != null ? ref.watch(assetsProvider) : null;

    // 🚫 BLOCK: Must have a crop/livestock selected to create an activity
    if (!hierarchy.hasCropOrLivestock) {
      return const ShellPageContent(
        title: 'Record Activity',
        subtitle: 'Select a crop or livestock first',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('Select a Crop or Livestock record first to create an activity.',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return ShellPageContent(
      title: 'Record Activity',
      subtitle: hierarchy.hasCropOrLivestock
          ? '${hierarchy.cropOrLivestockType == 'livestock' ? '🐄' : '🌱'} ${hierarchy.cropOrLivestockType == 'livestock' ? (hierarchy.cropOrLivestock as dynamic)?.species ?? '' : (hierarchy.cropOrLivestock as dynamic)?.cropName ?? ''}'
          : '',
      child: farmId == null
          ? const Center(child: Text('Select a farm first'))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hierarchy Context Banner ──
                  _buildHierarchyContextBanner(hierarchy),
                  const SizedBox(height: 16),

                  // ── Template Workflow Entry ──
                  _buildWorkflowBanner(context),
                  const SizedBox(height: 16),
                  _buildOrDivider(),
                  const SizedBox(height: 16),

                  // ── Quick Activity Form ──
                  Form(
                    key: _formKey,
                    child: _buildQuickForm(context, assetState, farmId, hierarchy),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHierarchyContextBanner(HierarchySelectionState hierarchy) {
    final fieldName = hierarchy.field?.fieldName ?? 'Field';
    final cropOrLivestockLabel = hierarchy.cropOrLivestockType == 'livestock'
        ? (hierarchy.cropOrLivestock as dynamic)?.species ?? 'Livestock'
        : (hierarchy.cropOrLivestock as dynamic)?.cropName ?? 'Crop';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            hierarchy.cropOrLivestockType == 'livestock' ? Icons.pets : Icons.eco,
            size: 18, color: Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recording activity for: $cropOrLivestockLabel in $fieldName',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Guided Agricultural Workflows',
                style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use pre-built templates for common farm operations like maize planting, dairy milking, poultry feeding, and more.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToTemplates(context),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Browse Workflow Templates'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR quick activity', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildQuickForm(
    BuildContext context,
    dynamic assetState,
    String farmId,
    HierarchySelectionState hierarchy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Simple form with basic fields', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 12),

        // Activity Type
        Text('Activity Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityTypes.map((type) {
            final isSelected = _activityTypeId == type.$1;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.$3, size: 16, color: isSelected ? Colors.white : type.$4),
                  const SizedBox(width: 6),
                  Text(type.$2),
                ],
              ),
              selected: isSelected,
              selectedColor: type.$4,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
              onSelected: (_) => setState(() => _activityTypeId = type.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Asset Selection
        Text('Related Asset (Optional)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (assetState != null && assetState.isLoading)
          const LoadingStateWidget()
        else if (assetState != null && assetState.assets.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _selectedAssetId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: 'Select an asset (optional)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...assetState.assets.map((asset) => DropdownMenuItem(
                value: asset.id,
                child: Text('${asset.assetName} (${asset.typeLabel})'),
              )),
            ],
            onChanged: (value) => setState(() => _selectedAssetId = value),
          )
        else
          Text('No assets available.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 20),

        // Date & Time
        Text('Date & Time', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickDateTime(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 12),
                Text('${_performedAt.day}/${_performedAt.month}/${_performedAt.year} '
                    '${_performedAt.hour.toString().padLeft(2, '0')}:${_performedAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Notes
        Text('Notes & Description', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: 'Describe the activity performed...',
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Please add a brief description' : null,
        ),
        const SizedBox(height: 32),

        if (_activityTypeId == 'harvesting') ...[
          _buildHarvestingOutputForm(context, hierarchy),
          const SizedBox(height: 32),
        ],

        // Submit
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _submitActivity(context, farmId),
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_isSubmitting ? 'Recording...' : 'Record Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestingOutputForm(
    BuildContext context,
    HierarchySelectionState hierarchy,
  ) {
    if (_commodities.isEmpty && !_loadingProductionReferences) {
      Future.microtask(_loadProductionReferences);
    }

    if (_loadingProductionReferences) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_productionReferencesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load production references: $_productionReferencesError',
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          TextButton.icon(
            onPressed: _loadProductionReferences,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final isLivestock = hierarchy.cropOrLivestockType == 'livestock';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Harvest Output',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isLivestock
              ? 'Livestock harvesting requires a canonical backend unit before it can be submitted.'
              : 'Record the output created by this harvesting activity.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Quantity',
            hintText: 'e.g. 10',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (_activityTypeId != 'harvesting') return null;
            final quantity = double.tryParse(value?.trim() ?? '');
            if (quantity == null || quantity <= 0) return 'Enter a positive quantity';
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedUnitId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Unit',
            hintText: 'Select canonical unit',
          ),
          items: _units
              .map((unit) => DropdownMenuItem(
                    value: unit.id,
                    child: Text(unit.name),
                  ))
              .toList(),
          onChanged: isLivestock
              ? null
              : (value) => setState(() => _selectedUnitId = value),
          validator: (value) {
            if (_activityTypeId != 'harvesting') return null;
            if (isLivestock) {
              return 'Livestock harvesting is unavailable until a canonical unit is configured';
            }
            return value == null ? 'Select a unit' : null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCommodityId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Output commodity',
            hintText: 'Select canonical commodity',
          ),
          items: _commoditiesFor(hierarchy)
              .map((commodity) => DropdownMenuItem(
                    value: commodity.id,
                    child: Text(commodity.name),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedCommodityId = value),
          validator: (value) => _activityTypeId == 'harvesting' && value == null
              ? 'Select an output commodity'
              : null,
        ),
      ],
    );
  }

  void _navigateToTemplates(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityTemplateSelectionPage()));
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _performedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_performedAt));
    if (time == null) return;
    setState(() => _performedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submitActivity(BuildContext context, String farmId) async {
    if (!_formKey.currentState!.validate()) return;

    // ── Guest mode: show sign-up prompt instead of saving ──
    final shouldProceed = await showProtectedActionPrompt(
      context,
      ref,
      action: 'save this activity record',
    );
    if (!shouldProceed) return;

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(farmRepositoryProvider);
      final hierarchy = ref.read(hierarchyProvider);

      // ── EXPLICIT WORKFLOW ──
      // Activities require the full Farm → Field → Crop/Livestock path.
      // Without a selected crop/livestock the activity would have no
      // documented hierarchy context (the activities table has no
      // farm/field/crop columns), so submission is blocked here rather
      // than silently recording an unlinked activity.
      if (!hierarchy.hasFullSelection) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select a Field and Crop/Livestock before recording an activity.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (_activityTypeId == 'harvesting' &&
          hierarchy.cropOrLivestockType == 'livestock') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Livestock harvesting is unavailable until a canonical output unit is configured.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Build activity model with UI context fields (NOT persisted to backend)
      // Authoritative contract: activity.asset_id = the selected crop/livestock
      // ASSET instance. The crop/livestock id in the hierarchy IS the asset id.
      final activity = ActivityModel(
        id: '', // Backend will generate
        activityTypeId: _activityTypeId,
        farmId: farmId, // UI context only
        fieldId: hierarchy.fieldId, // UI context only
        cropOrLivestockId: hierarchy.cropOrLivestockId, // UI context only
        cropOrLivestockType: hierarchy.cropOrLivestockType, // UI context only
        performedAt: _performedAt,
        notes: _notesController.text.trim(),
        assetId: hierarchy.cropOrLivestockId ?? _selectedAssetId,
        planId: null,
      );

      // Create activity via the create_activity RPC — only documented
      // activity columns are sent.
      final createdActivity = await repository.createActivity(activity: activity);

      // Invalidate activities + central mutation refresh (dashboard,
      // lifecycle, AI context)
      ref.invalidate(activitiesProvider);
      if (_activityTypeId == 'harvesting') {
        final quantity = double.parse(_quantityController.text.trim());
        try {
          await repository.recordProduction(
            farmId: farmId,
            production: ProductionEntity(
              id: '',
              activityId: createdActivity.id,
              quantity: quantity,
              unitId: _selectedUnitId,
              outputCommodityId: _selectedCommodityId,
              sourceType: 'activity',
              assetId: hierarchy.cropOrLivestockId,
            ),
          );
        } catch (e) {
          ref.invalidate(productionProvider);
          ref.invalidate(farmStockValueProvider);
          ref.invalidate(eligibleStockProvider);
          ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity saved, but production/stock failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
          return;
        }
        ref.invalidate(productionProvider);
        ref.invalidate(farmStockValueProvider);
        ref.invalidate(eligibleStockProvider);
      }
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity recorded successfully'), backgroundColor: Colors.green),
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