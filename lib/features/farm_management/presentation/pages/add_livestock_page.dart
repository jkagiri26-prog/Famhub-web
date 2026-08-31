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
class AddLivestockPage extends ConsumerStatefulWidget {
  const AddLivestockPage({super.key});

  @override
  ConsumerState<AddLivestockPage> createState() => _AddLivestockPageState();
}

class _AddLivestockPageState extends ConsumerState<AddLivestockPage> {
  final _formKey = GlobalKey<FormState>();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _countController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _speciesController.dispose();
    _breedController.dispose();
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

              // ── Species ──
              Text('Species',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _speciesController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Cattle, Goats, Chickens',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter species' : null,
              ),
              const SizedBox(height: 20),

              // ── Breed ──
              Text('Breed (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Friesian, Boer, Rhode Island Red',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
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
      final livestock = LivestockEntity(
        id: '',
        farmId: farmId,
        fieldId: fieldId,
        species: _speciesController.text.trim(),
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        count: int.parse(_countController.text.trim()),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await repository.createLivestock(farmId: farmId, livestock: livestock);
      ref.invalidate(livestockProvider);
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livestock added successfully'), backgroundColor: Colors.green),
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
