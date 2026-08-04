/// ============================================================
/// CREATE PROFILE PAGE — First-time profile creation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Collect user's first name (required)
///   - Display country read-only (from OTP session context)
///   - Searchable dropdowns for County (required), Sub-County, Ward
///   - Save profile to Supabase with location UUIDs
///   - Call onComplete when profile is saved
///
/// ❌ Does NOT:
///   - Allow free-text for location fields (backend contract)
///   - Handle navigation
/// ============================================================
library famhub_app.features.profile.presentation.pages.create_profile_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';

/// Provider that fetches county-level locations for a given country.
/// Uses geography_levels to find the correct level, then locations.
final _countiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, countryId) async {
  if (countryId.isEmpty) return [];
  final supabase = SupabaseService.instance;

  final levelResponse = await supabase
      .from('geography_levels', schema: 'core')
      .select('id')
      .eq('level_name', 'county')
      .eq('country_id', countryId)
      .maybeSingle();

  if (levelResponse == null) return [];
  final levelId = levelResponse['id'] as String;

  final response = await supabase
      .from('locations', schema: 'core')
      .select('id, name')
      .eq('level_id', levelId)
      .eq('country_id', countryId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

/// Provider that fetches sub-county locations for a given county (parent_id).
final _subCountiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, countyId) async {
  if (countyId.isEmpty) return [];
  final supabase = SupabaseService.instance;

  final levelResponse = await supabase
      .from('geography_levels', schema: 'core')
      .select('id')
      .eq('level_name', 'sub_county')
      .maybeSingle();

  if (levelResponse == null) return [];
  final levelId = levelResponse['id'] as String;

  final response = await supabase
      .from('locations', schema: 'core')
      .select('id, name')
      .eq('level_id', levelId)
      .eq('parent_id', countyId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

/// Provider that fetches ward locations for a given sub-county (parent_id).
final _wardsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, subCountyId) async {
  if (subCountyId.isEmpty) return [];
  final supabase = SupabaseService.instance;

  final levelResponse = await supabase
      .from('geography_levels', schema: 'core')
      .select('id')
      .eq('level_name', 'ward')
      .maybeSingle();

  if (levelResponse == null) return [];
  final levelId = levelResponse['id'] as String;

  final response = await supabase
      .from('locations', schema: 'core')
      .select('id, name')
      .eq('level_id', levelId)
      .eq('parent_id', subCountyId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

/// ── Reusable Searchable Location Field ──
/// Uses Flutter's Autocomplete to let users search and pick a location.
/// Stores the backend UUID (never just the display name) via onSelected.
class _SearchableLocationField extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? selectedName;
  final String hint;
  final IconData prefixIcon;
  final ValueChanged<Map<String, dynamic>?> onSelected;

  const _SearchableLocationField({
    required this.items,
    required this.onSelected,
    this.selectedName,
    this.hint = 'Select',
    this.prefixIcon = Icons.place_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: selectedName ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return items.map((i) => i['name'] as String);
        }
        final query = textEditingValue.text.toLowerCase();
        return items
            .where((i) => (i['name'] as String).toLowerCase().contains(query))
            .map((i) => i['name'] as String);
      },
      displayStringForOption: (option) => option,
      onSelected: (selection) {
        Map<String, dynamic>? match;
        for (final item in items) {
          if (item['name'] == selection) {
            match = item;
            break;
          }
        }
        onSelected(match);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync controller when selectedName changes externally
        if (controller.text != (selectedName ?? '')) {
          controller.text = selectedName ?? '';
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(prefixIcon),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Icon(prefixIcon, size: 18, color: colorScheme.onSurfaceVariant),
                    title: Text(option, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable loading/error/empty state widget for location sections.
class _LocationStatus extends StatelessWidget {
  final String message;
  final bool isError;

  const _LocationStatus({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isError)
            Icon(Icons.error_outline, size: 18, color: color)
          else
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 14, color: color)),
          ),
        ],
      ),
    );
  }
}

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

  // Country from OTP session (read-only display)
  String? _countryId;
  String? _countryName;
  bool _countryLoaded = false;

  // County (required)
  String? _selectedCountyId;
  String? _selectedCountyName;
  // Sub-county (optional)
  String? _selectedSubCountyId;
  String? _selectedSubCountyName;
  // Ward (optional)
  String? _selectedWardId;
  String? _selectedWardName;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFormChanged);
    _loadCountryFromSession();
  }

  void _onFormChanged() {
    if (mounted) setState(() {}); // Rebuild for button enablement
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  /// Load country from the persisted OTP session.
  Future<void> _loadCountryFromSession() async {
    try {
      final session = await OtpSessionStorage.loadSession();
      if (!mounted) return;
      setState(() {
        _countryId = session?.countryId;
        _countryName = session?.countryName ?? 'Kenya';
        _countryLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _countryId = null;
        _countryName = 'Kenya';
        _countryLoaded = true;
      });
    }
  }

  /// Button enabled only when: first name valid AND county selected.
  bool get _canSubmit {
    return _firstNameController.text.trim().length >= 2 &&
        _selectedCountyId != null &&
        !_isLoading &&
        _countryLoaded;
  }

  Future<void> _createProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await ref.read(sessionProvider.notifier).createProfile(
          firstName: _firstNameController.text.trim(),
          countyId: _selectedCountyId,
          subCountyId: _selectedSubCountyId,
          wardId: _selectedWardId,
        );

    if (!mounted) return;

    if (success) {
      widget.onComplete();
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Failed to create profile. Please try again.';
      });
    }
  }

  /// ── Country Display (read-only from OTP session) ──
  Widget _buildCountryDisplay(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.public_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            _countryName ?? 'Kenya',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// ── County Section (required) ──
  Widget _buildCountySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'County *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (_countryId == null)
          const _LocationStatus(message: 'Loading country...')
        else
          ref.watch(_countiesProvider(_countryId!)).when(
            data: (counties) {
              if (counties.isEmpty) {
                return const _LocationStatus(
                  message: 'No counties available. Please contact support.',
                  isError: true,
                );
              }
              return _SearchableLocationField(
                items: counties,
                selectedName: _selectedCountyName,
                hint: 'Search and select county',
                prefixIcon: Icons.map_outlined,
                onSelected: (match) {
                  setState(() {
                    _selectedCountyId = match?['id'] as String?;
                    _selectedCountyName = match?['name'] as String?;
                    // Reset lower levels when county changes
                    _selectedSubCountyId = null;
                    _selectedSubCountyName = null;
                    _selectedWardId = null;
                    _selectedWardName = null;
                  });
                },
              );
            },
            loading: () => const _LocationStatus(message: 'Loading counties...'),
            error: (err, _) => const _LocationStatus(
              message: 'Failed to load counties. Please try again later.',
              isError: true,
            ),
          ),
      ],
    );
  }

  /// ── Sub-County Section (optional) ──
  Widget _buildSubCountySection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sub-County (Optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedCountyId == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Select a county first',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ref.watch(_subCountiesProvider(_selectedCountyId!)).when(
            data: (subCounties) {
              if (subCounties.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No sub-counties available',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return _SearchableLocationField(
                items: subCounties,
                selectedName: _selectedSubCountyName,
                hint: 'Search and select sub-county',
                prefixIcon: Icons.flag_outlined,
                onSelected: (match) {
                  setState(() {
                    _selectedSubCountyId = match?['id'] as String?;
                    _selectedSubCountyName = match?['name'] as String?;
                    // Reset ward when sub-county changes
                    _selectedWardId = null;
                    _selectedWardName = null;
                  });
                },
              );
            },
            loading: () => const _LocationStatus(message: 'Loading sub-counties...'),
            error: (err, _) => const _LocationStatus(
              message: 'Failed to load sub-counties.',
              isError: true,
            ),
          ),
      ],
    );
  }

  /// ── Ward Section (optional) ──
  Widget _buildWardSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ward (Optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedSubCountyId == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Select a sub-county first',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ref.watch(_wardsProvider(_selectedSubCountyId!)).when(
            data: (wards) {
              if (wards.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No wards available',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return _SearchableLocationField(
                items: wards,
                selectedName: _selectedWardName,
                hint: 'Search and select ward',
                prefixIcon: Icons.place_outlined,
                onSelected: (match) {
                  setState(() {
                    _selectedWardId = match?['id'] as String?;
                    _selectedWardName = match?['name'] as String?;
                  });
                },
              );
            },
            loading: () => const _LocationStatus(message: 'Loading wards...'),
            error: (err, _) => const _LocationStatus(
              message: 'Failed to load wards.',
              isError: true,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

              // ── First Name (required) ──
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

              // ── Country (read-only from OTP session) ──
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

              // ── County (required) ──
              _buildCountySection(theme, colorScheme),

              const SizedBox(height: 20),

              // ── Sub-County (optional) ──
              _buildSubCountySection(theme, colorScheme),

              const SizedBox(height: 20),

              // ── Ward (optional) ──
              _buildWardSection(theme, colorScheme),

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
                      Icon(Icons.error_outline, color: colorScheme.error, size: 20),
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
                  child: _isLoading
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
}