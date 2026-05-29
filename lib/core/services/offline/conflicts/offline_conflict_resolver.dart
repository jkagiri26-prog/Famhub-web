import 'offline_conflict_model.dart';
import 'offline_conflict_strategy.dart';

class ConflictResolver {
  Map<String, dynamic> resolve(
    ConflictItem conflict,
    ConflictStrategy strategy,
  ) {
    switch (strategy) {
      case ConflictStrategy.serverWins:
        return conflict.serverData;

      case ConflictStrategy.clientWins:
        return conflict.localData;

      case ConflictStrategy.merge:
        return {
          ...conflict.serverData,
          ...conflict.localData, // client overrides
        };
    }
  }
}