/// ============================================================
/// CREATE PROFILE PAGE — First-time profile creation (REFACTORED)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Collect First Name (required), Middle Name, Last Name
///   - Display country read-only (from SessionCountryProvider)
///   - Render DynamicLocationFields (purely driven by provider)
///   - Save profile via sessionProvider.createProfile
///   - Call onComplete when profile is saved
///
/// ❌ Does NOT:
///   - Fetch backend data directly
///   - Hardcode location level names
///   - Handle navigation
///   - Contain repository/datasource/Supabase calls
/// ============================================================
library famhub_app.features.profile.presentation.pages.create_profile_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';
import 'package:famhub_app/features/profile/presentation/widgets/dynamic_location_fields.dart';

class CreateProfilePage extends ConsumerStatefulWidget {
  /// Called when the profile has been successfully created.
  final VoidCallback onComplete;

  const CreateProfilePage({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _firstNameController = TextEditingController();

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  /// Button enabled only when first name is at least 2 characters.
  bool get _canSubmit {
    return _firstNameController.text.trim().length >= 2 && !_isSaving;
  }

  Future<void> _createProfile() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    // Get selected location entries from the dynamic location provider.
    // Index 0 → county_id, 1 → sub_county_id, 2 → ward_id (preserves
    // backward compatibility with existing profiles table columns).
    final entries =
        ref.read(profileLocationProvider.notifier).selectedEntries;

    String? countyId;
    String? subCountyId;
    String? wardId;
    for (var i = 0; i < entries.length; i++) {
      switch (i) {
        case 0:
          countyId = entries[i].locationId;
          break;
        case 1:
          subCountyId = entries[i].locationId;
          break;
        case 2:
          wardId = entries[i].locationId;
          break;
      }
    }

    final success = await ref.read(sessionProvider.notifier).createProfile(
          firstName: _firstNameController.text.trim(),
          countyId: countyId,
          subCountyId: subCountyId,
          wardId: wardId,
        );

    if (!mounted) return;

    if (success) {
      widget.onComplete();
    } else {
      setState(() {
        _isSaving = false;
        _error = 'Failed to create profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch country for initialization trigger
    final countryState = ref.watch(sessionCountryProvider);
    final countryId = countryState.countryId;

    // Initialize location hierarchy once country is available
    if (countryId != null) {
      ref.watch(profileLocationInitProvider(countryId));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Icon ──
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                'Create Your Profile',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit about yourself to personalize your experience.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── First Name * ──
              Text(
                'First Name *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g., Samuel',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),

              // ── Country (read-only from session) ──
              Text(
                'Country',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildCountryDisplay(colorScheme, theme),
              const SizedBox(height: 20),

              // ── Dynamic Location Fields ──
              if (countryId != null)
                const DynamicLocationFields()
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // ── Error ──
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Create Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _canSubmit ? _createProfile : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  /// ── Country Display (read-only from SessionCountryProvider) ──
  Widget _buildCountryDisplay(ColorScheme colorScheme, ThemeData theme) {
    final countryState = ref.watch(sessionCountryProvider);

    if (countryState.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading country...',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final country = countryState.country;
    final name = country?.name ?? 'Not available';
    final flag = country?.isoAlpha2 ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.public_outlined,
              size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            flag.isNotEmpty ? '$flag  $name' : name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}