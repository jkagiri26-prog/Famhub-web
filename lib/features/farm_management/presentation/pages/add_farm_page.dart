import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/guest/auth_guard.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_onboarding_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farm_management_page.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_created_success_dialog.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';
import 'package:famhub_app/features/profile/presentation/widgets/dynamic_location_fields.dart';

/// Add Farm form with automatic default field creation.
///
/// 🏗️ POLICY (FAMHUB Default Field Creation):
///   Create Farm → Save Farm → Auto-create "Main Field" → Select Main Field → Navigate to Field Dashboard
///   The user is never asked to create the first field manually.
///
/// The default field inherits the farm's total area and is named "Main Field".
class AddFarmPage extends ConsumerStatefulWidget {
  const AddFarmPage({super.key});

  @override
  ConsumerState<AddFarmPage> createState() => _AddFarmPageState();
}

class _AddFarmPageState extends ConsumerState<AddFarmPage> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _farmNameController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Farm location is selected from core.locations (independent of the
    // profile's location). Initialize the geography hierarchy for the
    // session country so the County / Sub-County / Ward pickers render.
    final countryId = ref.watch(sessionCountryIdProvider);
    if (countryId != null) {
      ref.watch(profileLocationInitProvider(countryId));
    }

    return ShellPageContent(
      title: 'Add New Farm',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header with icon ──
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.agriculture_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create Your Farm',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A default Main Field will be created automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Auto-field creation banner ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A "Main Field" will be automatically created with the farm\'s total area.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Farm Name ──
              Text(
                'Farm Name *',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _farmNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Green Valley Farm',
                  prefixIcon: const Icon(Icons.agriculture),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter farm name' : null,
              ),
              const SizedBox(height: 20),

              // ── Description ──
              Text(
                'Description (Optional)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. Mixed crop farm in the central region',
                  prefixIcon: const Icon(Icons.description_outlined),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ── Size / Area ──
              Text(
                'Total Area (hectares)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sizeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. 5.0',
                  prefixIcon: const Icon(Icons.straighten),
                  suffixText: 'ha',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Farm Location (County / Sub-County / Ward) ──
              Text(
                'Farm Location *',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the County, Sub-County and Ward where this farm is located.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (countryId != null)
                DynamicLocationFields(
                  hideCountry: true, // country auto-resolved from the session profile
                  onRetry: _retryLevels,
                  onChanged: _handleLocationsChanged,
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              const SizedBox(height: 32),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting ? 'Creating Farm...' : 'Create Farm & Auto-Create Main Field',
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Quick info about what happens next ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next?',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(1, 'Farm is created with your details'),
                    const SizedBox(height: 6),
                    _buildStepRow(2, 'A "Main Field" is auto-created with the farm\'s total area'),
                    const SizedBox(height: 6),
                    _buildStepRow(3, 'You are taken to the farm dashboard'),
                    const SizedBox(height: 6),
                    _buildStepRow(4, 'Start adding crops, livestock, or activities immediately'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  /// Rebuild after a location selection so the submit flow reads the
  /// latest values from the geography provider. Level 0 is the country
  /// (auto-resolved from the session profile); the farm's location levels
  /// are index 1 = County, 2 = Sub-County, 3 = Ward.
  void _handleLocationsChanged(List<SelectedLocationEntry> entries) {
    setState(() {});
  }

  /// Retry loading geography levels for the session country.
  void _retryLevels() {
    final countryId = ref.read(sessionCountryIdProvider);
    if (countryId == null) return;
    ref.read(profileLocationProvider.notifier).refresh(countryId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ── GUEST GUARD: block unauthenticated submission before any mutation ──
    final shouldProceed = await showProtectedActionPrompt(
      context,
      ref,
      action: 'create a farm',
    );
    if (!shouldProceed) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(farmRepositoryProvider);

      final size = double.tryParse(_sizeController.text.trim());

      // ── Farm location selected in THIS form (core.locations) ──
      // The farm's County / Sub-County / Ward are picked by the user and
      // are independent of the profile's location. The authoritative values
      // come from the geography provider's selectedLocations map. Real IDs
      // only — never fabricated. FarmRepositoryImpl.createFarm() rejects
      // the insert if any are missing (the columns are NOT NULL).
      final selected = ref.read(profileLocationProvider).selectedLocations;
      final countyId = selected[1]?.id;
      final subCountyId = selected[2]?.id;
      final wardId = selected[3]?.id;
      if (countyId == null || subCountyId == null || wardId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select the farm\'s County, Sub-County and Ward location.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final farmEntity = FarmEntity(
        id: '', // Will be assigned by backend
        farmName: _farmNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        size: size,
        countyId: countyId,
        subCountyId: subCountyId,
        wardId: wardId,
        isActive: true,
        isVerified: false,
      );

      // ═══════════════════════════════════════════════════
      // POLICY: Create Farm → Auto-create "Main Field"
      // ═══════════════════════════════════════════════════
      final (createdFarm, defaultField) =
          await repository.createFarmWithDefaultField(farm: farmEntity);

      if (!mounted) return;

      // ═══════════════════════════════════════════════════
      // POLICY: Automatically select this field in the hierarchyProvider
      // ═══════════════════════════════════════════════════
      ref.read(hierarchyProvider.notifier).selectEntity(createdFarm);
      ref.read(hierarchyProvider.notifier).selectField(defaultField);

      // Invalidate fields provider so it picks up the new field
      ref.invalidate(fieldsProvider);

      // ═══════════════════════════════════════════════════
      // POLICY: One-Time Success Experience
      // ═══════════════════════════════════════════════════
      ref.read(farmOnboardingProvider.notifier).onFarmCreated();

      if (!mounted) return;

      // Navigate to dashboard first, then show the success dialog
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const FarmManagementPage(),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create farm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

