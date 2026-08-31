/// ============================================================
/// ADD CROP PAGE — Contextual Form
/// ============================================================
///
/// 🏗️ HIERARCHY RULE:
///   Add Crop — ONLY accessible when a Field/Block is selected.
///   Automatically receives farmId + fieldId from hierarchy context.
///   User never selects the parent farm or field — pre-filled.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

/// Add Crop form. Requires a Field/Block to be selected in hierarchy.
///
/// farmId and fieldId are automatically read from hierarchy — user does NOT
/// pick them. This enforces: "you must be IN a field to plant a crop."
class AddCropPage extends ConsumerStatefulWidget {
  const AddCropPage({super.key});

  @override
  ConsumerState<AddCropPage> createState() => _AddCropPageState();
}

class _AddCropPageState extends ConsumerState<AddCropPage> {
  final _formKey = GlobalKey<FormState>();
  final _cropNameController = TextEditingController();
  final _varietyController = TextEditingController();
  final _areaPlantedController = TextEditingController();
  final _notesController = TextEditingController();
  CropStatus _status = CropStatus.planted;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _cropNameController.dispose();
    _varietyController.dispose();
    _areaPlantedController.dispose();
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

    // 🚫 BLOCK: No field selected — should not happen if button is hidden
    if (farmId == null || fieldId == null) {
      return const ShellPageContent(
        title: 'Add Crop',
        subtitle: 'Select a field first',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('Select a Field/Block first to add a crop.',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return ShellPageContent(
      title: 'Add Crop',
      subtitle: 'Planting in $fieldName ($farmName)',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Context banner (auto-passed parents) ──
              _buildContextBanner(farmName, fieldName),
              const SizedBox(height: 24),

              // ── Crop Name ──
              Text('Crop Name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cropNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Maize, Tomatoes',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter crop name' : null,
              ),
              const SizedBox(height: 20),

              // ── Variety ──
              Text('Variety (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _varietyController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Hybrid, H411',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Area Planted ──
              Text('Area Planted (hectares)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _areaPlantedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. 2.5',
                  suffixText: 'ha',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Status ──
              Text('Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<CropStatus>(
                value: _status,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: CropStatus.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(_statusIcon(s), size: 16, color: _statusColor(s)),
                      const SizedBox(width: 8),
                      Text(_statusLabel(s)),
                    ],
                  ),
                )).toList(),
                onChanged: (v) => setState(() => _status = v!),
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
                  hintText: 'Any additional notes...',
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
                  label: Text(_isSubmitting ? 'Adding...' : 'Add Crop'),
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
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Planting in: $fieldName › $farmName',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.green.shade800),
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
      action: 'add a crop',
    );
    if (!shouldProceed) return;

    final farmId = ref.read(farmContextProvider).farmId;
    final fieldId = ref.read(hierarchyProvider).fieldId;
    if (farmId == null || fieldId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);
      final crop = CropEntity(
        id: '',
        farmId: farmId,
        fieldId: fieldId,
        cropName: _cropNameController.text.trim(),
        variety: _varietyController.text.trim().isEmpty ? null : _varietyController.text.trim(),
        plantingDate: DateTime.now(),
        areaPlanted: double.tryParse(_areaPlantedController.text.trim()),
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await repository.createCrop(farmId: farmId, crop: crop);
      ref.invalidate(cropsProvider);
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crop added successfully'), backgroundColor: Colors.green),
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

  String _statusLabel(CropStatus status) {
    switch (status) {
      case CropStatus.planted: return 'Planted';
      case CropStatus.growing: return 'Growing';
      case CropStatus.harvested: return 'Harvested';
      case CropStatus.failed: return 'Failed';
    }
  }

  IconData _statusIcon(CropStatus status) {
    switch (status) {
      case CropStatus.planted: return Icons.eco;
      case CropStatus.growing: return Icons.trending_up;
      case CropStatus.harvested: return Icons.shopping_basket;
      case CropStatus.failed: return Icons.warning;
    }
  }

  Color _statusColor(CropStatus status) {
    switch (status) {
      case CropStatus.planted: return Colors.blue;
      case CropStatus.growing: return Colors.green;
      case CropStatus.harvested: return Colors.orange;
      case CropStatus.failed: return Colors.red;
    }
  }
}
