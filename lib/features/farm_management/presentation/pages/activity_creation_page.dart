import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activity_type_catalog_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_live_providers.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/utils/activity_type_scope.dart';
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
  ConsumerState<ActivityCreationPage> createState() =>
      _ActivityCreationPageState();
}

class _ActivityCreationPageState extends ConsumerState<ActivityCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _quantityController = TextEditingController();
  final _dateController = TextEditingController();

  /// Selected quick-form activity type — a live `activity_types` catalog
  /// entry (real id → always resolvable by create_activity).
  ActivityTypeOption? _selectedType;
  String? _selectedCommodityId;
  String? _selectedUnitId;
  DateTime _performedAt = DateTime.now();
  bool _isSubmitting = false;
  bool _loadingProductionReferences = false;
  String? _productionReferencesError;
  List<({String id, String name, String category})> _commodities = [];
  List<({String id, String name})> _units = [];

  /// Harvesting output fields are only relevant for the harvesting type.
  bool get _isHarvesting =>
      _selectedType?.name.toLowerCase() == 'harvesting';

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDateTime(_performedAt);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    _dateController.dispose();
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

  /// Activity types relevant to the currently selected asset kind
  /// (crop vs livestock), straight from the live catalog.
  List<ActivityTypeOption> _filteredTypes(
    List<ActivityTypeOption> allTypes,
    String assetType,
  ) {
    return allTypes
        .where((t) =>
            activityTypeAppliesTo(
              name: t.name,
              category: t.category,
              assetType: assetType,
            ))
        .toList();
  }

  /// Keeps the selection inside the filtered list (first catalog load or a
  /// changed asset kind). Only assigns local fields this same build renders,
  /// so it is safe to call during build without setState.
  void _syncSelection(List<ActivityTypeOption> options) {
    if (options.isEmpty) {
      _selectedType = null;
      return;
    }
    final selected = _selectedType;
    if (selected != null && options.any((o) => o.id == selected.id)) {
      _selectedType = options.firstWhere((o) => o.id == selected.id);
      return;
    }
    _selectedType = options.firstWhere(
      (o) => o.name.toLowerCase() == 'general',
      orElse: () => options.first,
    );
  }

  String _assetLabel(HierarchySelectionState hierarchy) {
    final asset = hierarchy.cropOrLivestock;
    if (asset is CropEntity) return asset.cropName;
    if (asset is LivestockEntity) return asset.species;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final hierarchy = ref.watch(hierarchyProvider);
    final catalogAsync = ref.watch(activityTypeCatalogProvider);

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
              Text(
                'Select a Crop or Livestock record first to create an activity.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final assetType = hierarchy.cropOrLivestockType ?? kAssetTypeCrop;
    final isLivestock = assetType == kAssetTypeLivestock;
    final assetLabel = _assetLabel(hierarchy);

    return ShellPageContent(
      title: 'Record Activity',
      subtitle: '${isLivestock ? '🐄' : '🌱'} $assetLabel',
      child: farmId == null
          ? const Center(child: Text('Select a farm first'))
          : catalogAsync.when(
              loading: () =>
                  const LoadingStateWidget(message: 'Loading activity types…'),
              error: (error, _) => _buildCatalogError(),
              data: (allTypes) {
                final options = _filteredTypes(allTypes, assetType);
                _syncSelection(options);
                if (options.isEmpty) {
                  return _buildNoTypesState(isLivestock);
                }
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Where this activity will be recorded ──
                        _buildContextBanner(hierarchy, assetLabel),
                        const SizedBox(height: 16),

                        // ── Quick activity form ──
                        _buildQuickFormCard(
                          context,
                          farmId,
                          hierarchy,
                          options,
                          assetType,
                        ),
                        const SizedBox(height: 20),

                        // ── Guided workflow entry ──
                        _buildOrDivider('OR use a guided workflow'),
                        const SizedBox(height: 12),
                        _buildWorkflowBanner(context),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTEXT BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildContextBanner(
    HierarchySelectionState hierarchy,
    String assetLabel,
  ) {
    final isLivestock = hierarchy.cropOrLivestockType == 'livestock';
    final color = isLivestock ? Colors.brown : Colors.green;
    final fieldName = hierarchy.field?.fieldName ?? 'Field';
    final farmName = hierarchy.entity?.farmName ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLivestock ? Icons.pets : Icons.eco,
              size: 20,
              color: color.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording for $assetLabel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  farmName.isEmpty ? fieldName : '$fieldName · $farmName',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // QUICK FORM CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuickFormCard(
    BuildContext context,
    String farmId,
    HierarchySelectionState hierarchy,
    List<ActivityTypeOption> options,
    String assetType,
  ) {
    final theme = Theme.of(context);
    final assetWord = assetType == kAssetTypeLivestock ? 'livestock' : 'crop';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──
            Row(
              children: [
                Icon(Icons.edit_note, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick Activity',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Log a single activity in a few taps.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),

            // ── Activity type ──
            _SectionHeader(
              icon: Icons.category_outlined,
              title: 'Activity type',
              caption:
                  'Showing ${options.length} types relevant to this $assetWord',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((type) {
                final (icon, color) = _typePresentation(type.name);
                final isSelected = _selectedType?.id == type.id;
                return ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : color,
                  ),
                  label: Text(_prettyTypeName(type.name)),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  selected: isSelected,
                  selectedColor: color,
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected ? color : color.withValues(alpha: 0.35),
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Date & time ──
            const _SectionHeader(
              icon: Icons.schedule,
              title: 'When did it happen?',
              caption:
                  'Backdate up to 30 days — activities can’t be logged in the future.',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: () => _pickDateTime(context),
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                suffixIcon:
                    const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                hintText: 'Select date & time',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: _validatePerformedAt,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Notes ──
            const _SectionHeader(
              icon: Icons.notes,
              title: 'Notes',
              caption: 'Required — describe what was done.',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Describe the activity performed...',
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Please add a brief description'
                  : null,
            ),

            if (_isHarvesting) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildHarvestingOutputForm(context, hierarchy),
            ],

            const SizedBox(height: 20),

            // ── Submit ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    _isSubmitting ? null : () => _submitActivity(context, farmId),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Recording...' : 'Record Activity'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Couldn’t load activity types',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(activityTypeCatalogProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTypesState(bool isLivestock) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isLivestock ? Icons.pets : Icons.eco,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No activity types available for this ${isLivestock ? 'livestock' : 'crop'} yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GUIDED WORKFLOW ENTRY
  // ─────────────────────────────────────────────────────────────
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
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Guided Agricultural Workflows',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontSize: 15),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HARVEST OUTPUT
  // ─────────────────────────────────────────────────────────────
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
        _SectionHeader(
          icon: Icons.shopping_basket,
          title: 'Harvest output',
          caption: isLivestock
              ? 'Livestock harvesting requires a canonical backend unit before it can be submitted.'
              : 'Record the output created by this harvesting activity.',
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Quantity',
            hintText: 'e.g. 10',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (!_isHarvesting) return null;
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
            if (!_isHarvesting) return null;
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
          validator: (value) =>
              _isHarvesting && value == null ? 'Select an output commodity' : null,
        ),
      ],
    );
  }

  void _navigateToTemplates(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ActivityTemplateSelectionPage()));
  }

  String? _validatePerformedAt(String? _) {
    // The picker clamps future times already — this is a submission-time
    // backstop against clock skew so the backend's `performed_at <= now()`
    // checks can never reject the record with a raw SQL error.
    if (_performedAt.isAfter(DateTime.now())) {
      return 'Activities can’t be logged in the future';
    }
    return null;
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _performedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_performedAt),
    );
    if (time == null || !context.mounted) return;

    var picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final now = DateTime.now();
    final wasClamped = picked.isAfter(now);
    if (wasClamped) picked = now;

    setState(() {
      _performedAt = picked;
      _dateController.text = _formatDateTime(_performedAt);
    });

    if (wasClamped) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activities can’t be logged in the future — time set to now.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} '
        '${dt.year} · $hh:$mm';
  }

  /// Icon + colour for a catalog type, derived from its name so unknown
  /// future types still get a sensible glyph.
  (IconData, Color) _typePresentation(String name) {
    final n = name.toLowerCase();
    if (n.contains('plant')) return (Icons.eco, Colors.green);
    if (n.contains('irrigat') || n.contains('water')) {
      return (Icons.water_drop, Colors.cyan);
    }
    if (n.contains('fertiliz')) return (Icons.biotech, Colors.teal);
    if (n.contains('weed')) return (Icons.grass, Colors.lightGreen);
    if (n.contains('pest') || n.contains('spray') || n.contains('protect')) {
      return (Icons.bug_report, Colors.orange);
    }
    if (n.contains('harvest')) return (Icons.shopping_basket, Colors.green);
    if (n.contains('feed')) return (Icons.restaurant, Colors.brown);
    if (n.contains('milk') || n.contains('dairy')) {
      return (Icons.water, Colors.lightBlue);
    }
    if (n.contains('vaccin') || n.contains('medic')) {
      return (Icons.medical_services, Colors.red);
    }
    if (n.contains('inspect')) return (Icons.visibility, Colors.purple);
    if (n.contains('transport') || n.contains('ship')) {
      return (Icons.local_shipping, Colors.indigo);
    }
    if (n.contains('mainten')) return (Icons.build, Colors.blueGrey);
    if (n.contains('other')) return (Icons.more_horiz, Colors.grey);
    if (n.contains('general')) return (Icons.event_note, Colors.blue);
    return (Icons.local_activity, Colors.blueGrey);
  }

  /// 'pest_control' → 'Pest Control', 'feeding' → 'Feeding', …
  String _prettyTypeName(String name) {
    return name
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _submitActivity(BuildContext context, String farmId) async {
    if (!_formKey.currentState!.validate()) return;

    final selectedType = _selectedType;
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an activity type first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ── Guest mode: show sign-up prompt instead of saving ──
    final shouldProceed = await showProtectedActionPrompt(
      context,
      ref,
      action: 'save this activity record',
    );
    if (!shouldProceed || !context.mounted) return;

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
        if (!context.mounted) return;
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

      // Backend rejects future timestamps with a raw SQL error — guard here
      // so the farmer sees a friendly message instead.
      if (_performedAt.isAfter(DateTime.now())) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activities can’t be logged in the future.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_isHarvesting &&
          hierarchy.cropOrLivestockType == 'livestock') {
        if (!context.mounted) return;
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
        activityTypeId: selectedType.id,
        farmId: farmId, // UI context only
        fieldId: hierarchy.fieldId, // UI context only
        cropOrLivestockId: hierarchy.cropOrLivestockId, // UI context only
        cropOrLivestockType: hierarchy.cropOrLivestockType, // UI context only
        performedAt: _performedAt,
        notes: _notesController.text.trim(),
        assetId: hierarchy.cropOrLivestockId,
        planId: null,
      );

      // Create activity via the create_activity RPC — only documented
      // activity columns are sent.
      final createdActivity =
          await repository.createActivity(activity: activity);

      // Invalidate activities + central mutation refresh (dashboard,
      // lifecycle, AI context)
      ref.invalidate(activitiesProvider);
      if (_isHarvesting) {
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
          if (!context.mounted) return;
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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Activity recorded successfully'),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

/// Consistent labelled section header used across the quick form.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? caption;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 1),
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
