/// ============================================================
/// DYNAMIC LOCATION FIELDS — Builds dropdowns from geography metadata
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/widgets/ = profile widget catalog
///
/// ✅ Responsibilities:
///   - Watch ProfileLocationProvider
///   - Render a dynamic list of dropdowns based on geography levels
///   - Level 0 (country) is selectable, pre‑selected with the session country
///   - [hideCountry] hides the country dropdown while still auto-selecting
///     it from the session/profile so the lower levels cascade correctly
///   - Wire parent-child cascading (selecting a parent loads children)
///   - Expose selected location IDs for saving
///
/// ❌ Does NOT:
///   - Call backends directly
///   - Determine the country (reads from SessionCountryProvider)
///   - Hardcode any geography level names (County, Ward, etc.)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';
import 'package:famhub_app/shared/widgets/inputs/dynamic_location_dropdown.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';

/// Callback with the selected location entries ready to save.
typedef OnLocationsSelected = void Function(List<SelectedLocationEntry> entries);

class DynamicLocationFields extends ConsumerWidget {
  final OnLocationsSelected? onChanged;
  final VoidCallback? onRetry;

  /// When true, the country (level 0) dropdown is hidden. The country is
  /// still auto-resolved from the session/profile and used to drive the
  /// parent-child cascade for the levels below it.
  final bool hideCountry;

  const DynamicLocationFields({
    super.key,
    this.onChanged,
    this.onRetry,
    this.hideCountry = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileLocationProvider);
    final notifier = ref.read(profileLocationProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // ── Read the session country for auto‑selection ──
    final sessionCountry = ref.watch(sessionCountryIdProvider);
    final sessionCountryState = ref.watch(sessionCountryProvider);

    // Still loading the geography levels themselves
    if (state.isLoadingLevels) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Error loading levels — show retry
    if (state.levelsError != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.levelsError!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ),
          ],
        ],
      );
    }

    // No levels available — shouldn't happen for a valid country
    if (state.levels.isEmpty) {
      return const SizedBox.shrink();
    }

    // ── Build dropdowns dynamically ──
    final levels = state.levels;
    final dropdowns = <Widget>[];

    // We always start at level 0 (country) now.
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      final selected = state.selectedLocations[i];
      final levelIndex = i;

      // Determine the parent location for this level
      String? parentId;
      String cacheKey;
      if (i == 0) {
        // Level 0 = root level (country)
        parentId = null;
        cacheKey = ProfileLocationState.rootCacheKey(level.id);
      } else {
        final parentSelected = state.selectedLocations[i - 1];
        parentId = parentSelected?.id;
        if (parentId == null) {
          // Child must wait for parent selection
          final parentLevelName = levels[i - 1].levelName;
          dropdowns.add(_buildDisabledHint(
            colorScheme,
            theme,
            level.levelName,
            parentLevelName,
          ));
          continue;
        }
        cacheKey = ProfileLocationState.childCacheKey(level.id, parentId);
      }

      final locations = state.locationCache[cacheKey] ?? [];
      final isLoading = state.loadingLocationKeys.contains(cacheKey);
      final error = state.locationErrors[cacheKey];

      final dropdownItems = locations
          .map((l) => DropdownLocation(id: l.id, name: l.name))
          .toList();

      final selectedDropdown = selected != null
          ? DropdownLocation(id: selected.id, name: selected.name)
          : null;

      // Level 0 = country; selectable, with the session country auto‑selected as default.
      final bool isCountryLevel = i == 0;

      // ── Auto‑select the session country as soon as it's available ──
      if (isCountryLevel &&
          sessionCountry != null &&
          sessionCountry.isNotEmpty &&
          locations.isNotEmpty &&
          selected == null &&
          !isLoading) {
        // Attempt to find the location matching the session country ID.
        // The country location's ID or name must match; we try ID first, then name.
        GeoLocation? countryLoc;
        for (final loc in locations) {
          if (loc.id == sessionCountry ||
              loc.name.toLowerCase() ==
                  (sessionCountryState.country?.name ?? '').toLowerCase()) {
            countryLoc = loc;
            break;
          }
        }
        if (countryLoc != null) {
          // Use a post‑frame callback to avoid modifying state during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.selectLocation(0, countryLoc);
          });
        }
      }

      // ── Hide the country dropdown when requested ──
      // The country is still auto-selected above, so the cascade continues
      // to the first non-country level (County, etc.).
      if (isCountryLevel && hideCountry) {
        continue;
      }

      dropdowns.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DynamicLocationDropdown(
            levelName: level.levelName,
            isRequired: !isCountryLevel, // country defaults to the session country
            items: dropdownItems,
            selected: selectedDropdown,
            isLoading: isLoading,
            error: error,
            hint: isCountryLevel
                ? 'Select country'
                : 'Search and select ${level.levelName.toLowerCase()}',
            prefixIcon: isCountryLevel
                ? Icons.public_outlined
                : (levelIndex == 1 ? Icons.map_outlined : Icons.flag_outlined),
            enabled: true, // country is selectable; session country is the default
            onChanged: (picked) {
              if (picked == null) {
                notifier.selectLocation(levelIndex, null);
              } else {
                final geoLoc = locations.firstWhere(
                  (l) => l.id == picked.id,
                );
                notifier.selectLocation(levelIndex, geoLoc);
              }
              onChanged?.call(notifier.selectedEntries);
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dropdowns,
    );
  }

  /// Shown when a child dropdown is waiting for its parent to be selected.
  Widget _buildDisabledHint(
    ColorScheme colorScheme,
    ThemeData theme,
    String levelName,
    String parentLevelName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$levelName *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Select ${parentLevelName.toLowerCase()} first',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}