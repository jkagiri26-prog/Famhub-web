/// ============================================================
/// ADD FIELD PAGE — Contextual Form
/// ============================================================
///
/// 🏗️ HIERARCHY RULE:
///   Add Field/Block — ONLY accessible when a Farm/Entity is selected.
///   Automatically receives farmId from hierarchy context.
///   User never selects the parent farm — it's pre-filled.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_cascade_coordinator.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';

/// Add Field/Block form. Requires a farm to be selected in context.
///
/// The farmId is automatically read from hierarchy — the user does NOT
/// pick it. This enforces: "you must be IN a farm to create a field."
class AddFieldPage extends ConsumerStatefulWidget {
  const AddFieldPage({super.key});

  @override
  ConsumerState<AddFieldPage> createState() => _AddFieldPageState();
}

class _AddFieldPageState extends ConsumerState<AddFieldPage> {
  final _formKey = GlobalKey<FormState>();
  final _fieldNameController = TextEditingController();
  final _acreageController = TextEditingController();
  final _soilTypeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isActive = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fieldNameController.dispose();
    _acreageController.dispose();
    _soilTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmCtx = ref.watch(farmContextProvider);
    final farmId = farmCtx.farmId;
    final farmName = farmCtx.farm?.farmName ?? 'Farm';

    return ShellPageContent(
      title: 'Add Field / Block',
      subtitle: farmId != null
          ? 'Adding to $farmName'
          : 'Select a farm first',
      child: farmId == null
          ? const Center(child: Text('No farm selected. Please select a farm first.'))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Auto-filled farm context indicator ──
                    _buildContextBanner(farmName),
                    const SizedBox(height: 24),

                    // ── Field Name ──
                    Text('Field / Block Name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fieldNameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'e.g. North Field, Plot A',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter field name' : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Acreage ──
                    Text('Acreage (hectares)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _acreageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'e.g. 5.5',
                        suffixText: 'ha',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Soil Type ──
                    Text('Soil Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _soilTypeController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'e.g. Loam, Clay, Sandy',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Active Status (backend `is_active` — no status column) ──
                    Text('Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active field'),
                      subtitle: Text(_isActive
                          ? 'This field is in use'
                          : 'This field is inactive'),
                    ),
                    const SizedBox(height: 20),

                    // ── Notes (backend `description`) ──
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
                        label: Text(_isSubmitting ? 'Adding...' : 'Add Field / Block'),
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

  Widget _buildContextBanner(String? farmName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.agriculture, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Adding field to: $farmName',
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
      action: 'add a field',
    );
    if (!shouldProceed) return;

    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);
      final field = FieldEntity(
        id: '',
        farmId: farmId,
        fieldName: _fieldNameController.text.trim(),
        acreage: double.tryParse(_acreageController.text.trim()),
        soilType: _soilTypeController.text.trim().isEmpty ? null : _soilTypeController.text.trim(),
        isActive: _isActive,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await repository.createField(farmId: farmId, field: field);
      ref.invalidate(fieldsProvider);
      ref.read(hierarchyCascadeCoordinatorProvider).refreshAfterMutation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field added successfully'), backgroundColor: Colors.green),
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
