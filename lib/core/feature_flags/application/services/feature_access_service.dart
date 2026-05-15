import '../../domain/models/feature_flag.dart';

class FeatureAccessService {
  const FeatureAccessService._();

  /// Evaluates access using backend-driven feature flags.
  ///
  /// Rules:
  /// backend > frontend assumptions
  ///
  /// Returns false if:
  /// - feature does not exist
  /// - feature is disabled
  /// - feature is under maintenance
  /// - feature requires premium access
  /// - feature requires admin access
  static bool canAccessFeature({
    required String featureKey,
    required Map<String, FeatureFlag> featureFlags,
    required bool isPremiumUser,
    required bool isAdmin,
  }) {
    final flag = featureFlags[featureKey];

    /// Feature not configured = deny access
    if (flag == null) {
      return false;
    }

    /// Hard stop: disabled
    if (!flag.isEnabled) {
      return false;
    }

    /// Hard stop: maintenance mode
    if (flag.maintenanceMode) {
      return false;
    }

    /// Premium restriction
    if (flag.premiumOnly && !isPremiumUser) {
      return false;
    }

    /// Admin restriction
    if (flag.adminOnly && !isAdmin) {
      return false;
    }

    return true;
  }
}