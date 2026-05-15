import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/feature_flag.dart';
import '../../infrastructure/repositories/feature_flag_repository.dart';

final featureFlagRepositoryProvider =
    Provider<FeatureFlagRepository>((ref) {
  return FeatureFlagRepository();
});

final featureFlagsProvider =
    FutureProvider<Map<String, FeatureFlag>>((ref) async {
  final repository = ref.watch(featureFlagRepositoryProvider);

  final flags = await repository.fetchFeatureFlags();

  /// Convert list → map for O(1) lookup
  return {
    for (final flag in flags) flag.featureKey: flag,
  };
}