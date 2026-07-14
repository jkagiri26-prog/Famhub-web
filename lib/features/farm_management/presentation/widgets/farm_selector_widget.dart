/// ============================================================
/// FARM SELECTOR WIDGET — Dashboard Widget for Farm Selection
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/widgets/ = presentation widgets
///
/// ✅ Responsibilities:
///   - Display current farm name and allow switching between farms
///   - Used as a dashboard widget (farm_farm_selector)
///   - Connects to farmSelectorProvider for farm list + selection
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses providers (never direct Supabase calls)
///   - Wrapped in ModuleErrorBoundary by the dashboard renderer
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';

/// Farm Selector dashboard widget.
///
/// Registered as 'farm_farm_selector' in the WidgetRegistry.
class FarmSelectorWidget extends ConsumerWidget {
  const FarmSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectorState = ref.watch(farmSelectorProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Farm',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (selectorState.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (selectorState.farms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No farms found',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          else
            Column(
              children: [
                // Current farm display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.agriculture,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFarmName(selectorState),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectorState.farms.length > 1)
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                    ],
                  ),
                ),
                // Farm list (if more than one farm)
                if (selectorState.farms.length > 1) ...[
                  const SizedBox(height: 8),
                  ...selectorState.farms
                      .where((f) => f.id != selectorState.selectedFarmId)
                      .map((farm) => _farmOption(farm, ref)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _selectedFarmName(FarmSelectorState state) {
    if (state.selectedFarmId == null) return 'No farm selected';
    final farm = state.farms.cast<FarmEntity?>().firstWhere(
      (f) => f?.id == state.selectedFarmId,
      orElse: () => null,
    );
    return farm?.farmName ?? 'Unknown Farm';
  }

  Widget _farmOption(FarmEntity farm, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () {
          ref.read(farmSelectorProvider.notifier).selectFarm(farm.id);
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Row(
            children: [
              Icon(
                Icons.terrain,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                farm.farmName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
