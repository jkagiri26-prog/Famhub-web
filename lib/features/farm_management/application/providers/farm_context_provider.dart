import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/context_engine/providers/context_provider.dart';
import '../../../../core/context_engine/models/entity_context.dart';
import '../../domain/models/farm_entity.dart';
import 'farm_selector_provider.dart';

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

  final selectedFarm = selector.farms
      .where((f) => f.id == selectedFarmId)
      .cast<FarmEntity?>()
      .firstWhere(
        (f) => f != null,
        orElse: () => null,
      );

  return FarmContext(
    farmId: selectedFarmId,
    farm: selectedFarm,
    role: context.role,
  );
});