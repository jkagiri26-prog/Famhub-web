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
///   - Wire parent-child cascading (selecting a parent loads children)
///   - Expose selected location IDs for saving
///
/// ❌ Does NOT:
///   - Call backends directly
///   - Determine the country
///   - Hardcode any geography level names (County, Ward, etc.)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';
import 'package:famhub_app/shared/widgets/inputs/dynamic_location_dropdown.dart';

/// Callback with the selected location entries ready to save.
typedef OnLocationsSelected = void Function(List<SelectedLocationEntry> entries);

class DynamicLocationFields extends ConsumerWidget {
  final OnLocationsSelected? onChanged;
  final VoidCallback? onRetry;
  final bool skipCountryLevel;

  const DynamicLocationFields({
    super.key,
    this.onChanged,
    this.onRetry,
    this.skipCountryLevel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileLocationProvider);
    final notifier = ref.read(profileLocationProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

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
    final int renderStartIndex = skipCountryLevel && levels.isNotEmpty ? 1 : 0;

    // If skipping country level, ensure the first visible level loads its root locations
    if (skipCountryLevel && levels.length > 1) {
      final firstVisibleLevel = levels[1];
      final cacheKey = ProfileLocationState.rootCacheKey(firstVisibleLevel.id);
      if (!state.locationCache.containsKey(cacheKey) &&
          !state.loadingLocationKeys.contains(cacheKey)) {
        // Schedule loading in next frame to avoid build-side-effects
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifier.loadLocations(levelIndex: 1, parentId: null);
        });
      }
    }

    for (var i = renderStartIndex; i < levels.length; i++) {
      final level = levels[i];
      final selected = state.selectedLocations[i];
      var levelIndex = i;

      // Determine the parent location for this level
      String? parentId;
      String cacheKey;
      if (i == renderStartIndex) {
        parentId = null;
        cacheKey = ProfileLocationState.rootCacheKey(level.id);
      } else {
        final parentSelected = state.selectedLocations[i - 1];
        parentId = parentSelected?.id;
        if (parentId == null) {
          dropdowns.add(_buildDisabledHint(
            colorScheme,
            theme,
            level.levelName,
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

      dropdowns.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DynamicLocationDropdown(
            levelName: level.levelName,
            isRequired: true,
            items: dropdownItems,
            selected: selectedDropdown,
            isLoading: isLoading,
            error: error,
            hint: 'Search and select ${level.levelName.toLowerCase()}',
            prefixIcon: levelIndex == renderStartIndex
                ? Icons.map_outlined
                : Icons.flag_outlined,
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
            'Select parent ${levelName.toLowerCase()} first',
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