import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_entity.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';

class FarmContext {
  final String? farmId;
  final FarmEntity? farm;
  final String? role;

  const FarmContext({
    required this.farmId,
    required this.farm,
    required this.role,
  });
}

/// Resolves farm-specific context from Context Engine + Farm Selector
///
/// Rules:
/// - Context Engine = identity source
/// - Farm Selector = domain selection
/// - RLS = data security layer
final farmContextProvider = Provider<FarmContext>((ref) {
  final context = ref.watch(contextProvider);
  final selector = ref.watch(farmSelectorProvider);

  final selectedFarmId = selector.selectedFarmId;

    final selectedFarm = selector.selectedFarmId != null
      ? selector.farms.cast<FarmEntity?>().firstWhere(
          (f) => f?.id == selector.selectedFarmId,
          orElse: () => null,
        )
      : null;

  return FarmContext(
    farmId: selectedFarmId,
    farm: selectedFarm,
    role: context.role,
  );
});