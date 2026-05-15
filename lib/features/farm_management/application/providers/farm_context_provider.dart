import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/context/context_provider.dart';
import '../../domain/models/farm_entity.dart';
import 'farm_selector_provider.dart';

class FarmContext {
  final String? farmId;
  final FarmEntity? farm;
  final UserRole role;

  const FarmContext({
    required this.farmId,
    required this.farm,
    required this.role,
  });
}

/// Resolves farm-specific context from global app context + farm selector
///
/// Rules:
/// - Context Engine = identity source
/// - Farm Selector = domain selection
/// - RLS = data security layer
final farmContextProvider = Provider<FarmContext>((ref) {
  final appContext = ref.watch(contextProvider);
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
    role: appContext.role.activeRole,
  );
});