/// ============================================================
/// DYNAMIC LOCATION DROPDOWN — Reusable dropdown for one geography level
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/inputs/ = reusable widget catalog (shared across features)
///
/// ✅ Responsibilities:
///   - Pure presentation widget
///   - Display a single searchable dropdown for locations
///   - Show loading / error / empty states
///   - Call onChanged with the selected location
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Call backends or providers
///   - Know about geography hierarchy
///   - Import feature-specific providers
/// ============================================================
library;

import 'package:flutter/material.dart';

/// Simple location model used by the shared dropdown.
/// Kept here to avoid coupling the shared widget to profile providers.
class DropdownLocation {
  final String id;
  final String name;

  const DropdownLocation({required this.id, required this.name});
}

class DynamicLocationDropdown extends StatelessWidget {
  /// The display label for this dropdown (e.g. "County", "Sub-County").
  final String levelName;

  /// Whether this dropdown is required.
  final bool isRequired;

  /// The list of available locations.
  final List<DropdownLocation> items;

  /// The currently selected location.
  final DropdownLocation? selected;

  /// Whether locations are being loaded.
  final bool isLoading;

  /// Error message, if any.
  final String? error;

  /// Called when the user selects a location.
  final ValueChanged<DropdownLocation?> onChanged;

  /// Placeholder text when no item is selected.
  final String hint;

  /// Icon shown on the prefix.
  final IconData prefixIcon;

  /// Optional: enabled state.
  final bool enabled;

  const DynamicLocationDropdown({
    super.key,
    required this.levelName,
    this.isRequired = false,
    required this.items,
    this.selected,
    this.isLoading = false,
    this.error,
    required this.onChanged,
    this.hint = 'Select',
    this.prefixIcon = Icons.place_outlined,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──
        Text(
          isRequired ? '$levelName *' : '$levelName (Optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // ── Content ──
        _buildContent(colorScheme),
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    // Error state
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(fontSize: 14, color: colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (isLoading) {
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
              'Loading ${levelName.toLowerCase()}s...',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No ${levelName.toLowerCase()}s available',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // ── Searchable autocomplete dropdown ──
    return _SearchableDropdown(
      items: items,
      selected: selected,
      hint: hint,
      prefixIcon: prefixIcon,
      enabled: enabled,
      onSelected: onChanged,
    );
  }
}

/// ────────────────────────────────────────────────────────────
/// Internal: Searchable autocomplete dropdown
/// ────────────────────────────────────────────────────────────
class _SearchableDropdown extends StatelessWidget {
  final List<DropdownLocation> items;
  final DropdownLocation? selected;
  final String hint;
  final IconData prefixIcon;
  final bool enabled;
  final ValueChanged<DropdownLocation?> onSelected;

  const _SearchableDropdown({
    required this.items,
    this.selected,
    this.hint = 'Select',
    this.prefixIcon = Icons.place_outlined,
    this.enabled = true,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: selected?.name ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return items.map((i) => i.name);
        }
        final query = textEditingValue.text.toLowerCase();
        return items
            .where((i) => i.name.toLowerCase().contains(query))
            .map((i) => i.name);
      },
      displayStringForOption: (option) => option,
      onSelected: (selection) {
        DropdownLocation? match;
        for (final item in items) {
          if (item.name == selection) {
            match = item;
            break;
          }
        }
        onSelected(match);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync controller when selected changes externally
        if (controller.text != (selected?.name ?? '')) {
          controller.text = selected?.name ?? '';
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
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
                    leading: Icon(
                      prefixIcon,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
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