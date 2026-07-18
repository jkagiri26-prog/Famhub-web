/// ============================================================
/// CREATE PROFILE PAGE — First-time profile creation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Collect user's full name (required)
///   - Fetch countries from core.countries (default Kenya)
///   - Fetch counties from core.locations via geography_levels (required)
///   - Save profile to Supabase users.profiles table with location UUIDs
///   - Call onComplete when profile is saved
///
/// ❌ Does NOT:
///   - Handle navigation
///   - Know about session state
/// ============================================================
library famhub_app.features.profile.presentation.pages.create_profile_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

/// Provider that fetches active countries from core.countries.
final _countriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseService.instance;
  final response = await supabase
      .from('countries')
      .select('id, name, iso_alpha2')
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Provider that fetches county-level locations for a given country.
/// Uses geography_levels to find the correct level, then locations.
final _countiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, countryId) async {
  if (countryId.isEmpty) return [];
  final supabase = SupabaseService.instance;

  // Find the geography level ID for 'county'
  final levelResponse = await supabase
      .from('geography_levels')
      .select('id')
      .eq('level_name', 'county')
      .eq('country_id', countryId)
      .maybeSingle();

  if (levelResponse == null) return [];
  final levelId = levelResponse['id'] as String;

  // Fetch all locations at the county level for this country
  final response = await supabase
      .from('locations')
      .select('id, name')
      .eq('level_id', levelId)
      .eq('country_id', countryId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

class CreateProfilePage extends ConsumerStatefulWidget {
  /// Called when the profile has been successfully created.
  /// Passes the display name that was saved.
  final void Function(String displayName) onComplete;

  const CreateProfilePage({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

/// Provider that fetches sub-county locations for a given county (parent_id).
final _subCountiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, countyId) async {
  if (countyId.isEmpty) return [];
  final supabase = SupabaseService.instance;

  // Find the geography level ID for 'sub_county'
  final levelResponse = await supabase
      .from('geography_levels')
      .select('id')
      .eq('level_name', 'sub_county')
      .maybeSingle();

  if (levelResponse == null) {
    // Fallback: fetch all locations where parent_id = countyId
    final response = await supabase
        .from('locations')
        .select('id, name')
        .eq('parent_id', countyId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }
  final levelId = levelResponse['id'] as String;

  final response = await supabase
      .from('locations')
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

  // Find the geography level ID for 'ward'
  final levelResponse = await supabase
      .from('geography_levels')
      .select('id')
      .eq('level_name', 'ward')
      .maybeSingle();

  if (levelResponse == null) {
    // Fallback: fetch all locations where parent_id = subCountyId
    final response = await supabase
        .from('locations')
        .select('id, name')
        .eq('parent_id', subCountyId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }
  final levelId = levelResponse['id'] as String;

  final response = await supabase
      .from('locations')
      .select('id, name')
      .eq('level_id', levelId)
      .eq('parent_id', subCountyId)
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();

  // Country
  String? _selectedCountryId;
  String? _selectedCountryName;
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
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await ref.read(sessionProvider.notifier).createProfile(
          displayName: _fullNameController.text.trim(),
          preferredLanguage: 'en',
          countryId: _selectedCountryId,
          countryName: _selectedCountryName,
          countyId: _selectedCountyId,
          countyName: _selectedCountyName,
          subCountyId: _selectedSubCountyId,
          subCountyName: _selectedSubCountyName,
          wardId: _selectedWardId,
          wardName: _selectedWardName,
        );

    if (!mounted) return;

    if (success) {
      widget.onComplete(_fullNameController.text.trim());
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Failed to create profile. Please try again.';
      });
    }
  }

  /// ── Helpers: Auto-select Kenya as default country ──
  void _autoSelectKenya(List<Map<String, dynamic>> countries) {
    if (_selectedCountryId != null) return;
    for (final c in countries) {
      if (c['iso_alpha2'] == 'KE') {
        _selectedCountryId = c['id'] as String;
        _selectedCountryName = c['name'] as String;
        return;
      }
    }
    // Fallback to first country
    if (countries.isNotEmpty) {
      _selectedCountryId = countries.first['id'] as String;
      _selectedCountryName = countries.first['name'] as String;
    }
  }

  /// ── Country Dropdown Builder ──
  Widget _buildCountryDropdown(ColorScheme colorScheme, ThemeData theme) {
    final countriesAsync = ref.watch(_countriesProvider);

    return countriesAsync.when(
      data: (countries) {
        _autoSelectKenya(countries);
        return DropdownButtonFormField<String>(
          value: _selectedCountryId,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.public_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: countries.map((c) {
            return DropdownMenuItem(
              value: c['id'] as String,
              child: Text(c['name'] as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              final country = countries.firstWhere((c) => c['id'] == value);
              setState(() {
                _selectedCountryId = value;
                _selectedCountryName = country['name'] as String;
                // Reset lower levels when country changes
                _selectedCountyId = null;
                _selectedCountyName = null;
                _selectedSubCountyId = null;
                _selectedSubCountyName = null;
                _selectedWardId = null;
                _selectedWardName = null;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Country is required';
            }
            return null;
          },
        );
      },
      loading: () => const DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.public_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: Text('Loading countries...'),
      ),
      error: (err, _) => TextFormField(
        decoration: InputDecoration(
          hintText: 'Kenya',
          prefixIcon: const Icon(Icons.public_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        initialValue: 'Kenya',
        enabled: false,
      ),
    );
  }

  /// ── County Dropdown Builder ──
  Widget _buildCountyDropdown(ColorScheme colorScheme, ThemeData theme) {
    if (_selectedCountryId == null) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.map_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: const Text('Select a country first'),
      );
    }

    final countiesAsync = ref.watch(_countiesProvider(_selectedCountryId!));

    return countiesAsync.when(
      data: (counties) {
        if (counties.isEmpty) {
          return TextFormField(
            decoration: InputDecoration(
              hintText: 'Enter your county name',
              prefixIcon: const Icon(Icons.map_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'County is required';
              }
              return null;
            },
            onChanged: (value) {
              _selectedCountyName = value.trim();
            },
          );
        }
        return DropdownButtonFormField<String>(
          value: _selectedCountyId,
          hint: const Text('Select county'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.map_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: counties.map((c) {
            return DropdownMenuItem(
              value: c['id'] as String,
              child: Text(c['name'] as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              final county = counties.firstWhere((c) => c['id'] == value);
              setState(() {
                _selectedCountyId = value;
                _selectedCountyName = county['name'] as String;
                // Reset sub-county and ward when county changes
                _selectedSubCountyId = null;
                _selectedSubCountyName = null;
                _selectedWardId = null;
                _selectedWardName = null;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your county';
            }
            return null;
          },
        );
      },
      loading: () => const DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.map_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: Text('Loading counties...'),
      ),
      error: (err, _) => TextFormField(
        decoration: InputDecoration(
          hintText: 'Enter your county name',
          prefixIcon: const Icon(Icons.map_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'County is required';
          }
          return null;
        },
        onChanged: (value) {
          _selectedCountyName = value.trim();
        },
      ),
    );
  }

  /// ── Sub-County Dropdown Builder ──
  Widget _buildSubCountyDropdown(ColorScheme colorScheme, ThemeData theme) {
    if (_selectedCountyId == null) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.flag_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: const Text('Select a county first'),
      );
    }

    final subCountiesAsync = ref.watch(_subCountiesProvider(_selectedCountyId!));

    return subCountiesAsync.when(
      data: (subCounties) {
        if (subCounties.isEmpty) {
          return TextFormField(
            decoration: InputDecoration(
              hintText: 'Enter sub-county (optional)',
              prefixIcon: const Icon(Icons.flag_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _selectedSubCountyName = value.trim().isEmpty ? null : value.trim();
            },
          );
        }
        return DropdownButtonFormField<String>(
          value: _selectedSubCountyId,
          hint: const Text('Select sub-county (optional)'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.flag_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...subCounties.map((s) {
              return DropdownMenuItem(
                value: s['id'] as String,
                child: Text(s['name'] as String),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedSubCountyId = value;
              _selectedSubCountyName = value != null
                  ? subCounties.firstWhere((s) => s['id'] == value)['name'] as String
                  : null;
              // Reset ward when sub-county changes
              _selectedWardId = null;
              _selectedWardName = null;
            });
          },
        );
      },
      loading: () => const DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.flag_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: Text('Loading sub-counties...'),
      ),
      error: (err, _) => TextFormField(
        decoration: InputDecoration(
          hintText: 'Enter sub-county (optional)',
          prefixIcon: const Icon(Icons.flag_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          _selectedSubCountyName = value.trim().isEmpty ? null : value.trim();
        },
      ),
    );
  }

  /// ── Ward Dropdown Builder ──
  Widget _buildWardDropdown(ColorScheme colorScheme, ThemeData theme) {
    if (_selectedSubCountyId == null) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.place_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: const Text('Select a sub-county first'),
      );
    }

    final wardsAsync = ref.watch(_wardsProvider(_selectedSubCountyId!));

    return wardsAsync.when(
      data: (wards) {
        if (wards.isEmpty) {
          return TextFormField(
            decoration: InputDecoration(
              hintText: 'Enter ward (optional)',
              prefixIcon: const Icon(Icons.place_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _selectedWardName = value.trim().isEmpty ? null : value.trim();
            },
          );
        }
        return DropdownButtonFormField<String>(
          value: _selectedWardId,
          hint: const Text('Select ward (optional)'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.place_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...wards.map((w) {
              return DropdownMenuItem(
                value: w['id'] as String,
                child: Text(w['name'] as String),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedWardId = value;
              _selectedWardName = value != null
                  ? wards.firstWhere((w) => w['id'] == value)['name'] as String
                  : null;
            });
          },
        );
      },
      loading: () => const DropdownButtonFormField<String>(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.place_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: [],
        onChanged: null,
        hint: Text('Loading wards...'),
      ),
      error: (err, _) => TextFormField(
        decoration: InputDecoration(
          hintText: 'Enter ward (optional)',
          prefixIcon: const Icon(Icons.place_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          _selectedWardName = value.trim().isEmpty ? null : value.trim();
        },
      ),
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
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ── Avatar ──
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.person_add_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                const SizedBox(height: 32),

                // ── Full Name (required) ──
                Text(
                  'Full Name *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Samuel Karanja',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Country (required, default Kenya) ──
                Text(
                  'Country *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCountryDropdown(colorScheme, theme),

                const SizedBox(height: 20),

                // ── County (required) ──
                Text(
                  'County *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCountyDropdown(colorScheme, theme),
                const SizedBox(height: 20),

                // ── Sub-County (optional) ──
                Text(
                  'Sub-County (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSubCountyDropdown(colorScheme, theme),
                const SizedBox(height: 20),

                // ── Ward (optional) ──
                Text(
                  'Ward (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildWardDropdown(colorScheme, theme),

                // ── Info Note ──
                const SizedBox(height: 16),

                // ── Error ──
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
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

                const SizedBox(height: 32),

                // ── Create Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _createProfile,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
      ),
    );
  }
}
