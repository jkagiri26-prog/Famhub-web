import '../../domain/models/feature_flag.dart';
import '../../../../core/services/supabase_service.dart';

class FeatureFlagRepository {
  const FeatureFlagRepository();

  Future<List<FeatureFlag>> fetchFeatureFlags() async {
    try {
      final response =
          await SupabaseService.client.rpc('get_feature_flags');

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;

      return data
          .map(
            (item) => FeatureFlag.fromMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      /// Never use print() in repositories
      /// Future upgrade:
      /// route errors to centralized logging service
      return [];
    }
  }
}