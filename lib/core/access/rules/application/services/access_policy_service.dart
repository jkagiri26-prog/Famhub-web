import '../../domain/models/access_policy.dart';

class AccessPolicyService {
  AccessPolicy? _cachedPolicy;

  /// Store latest policy in memory
  void setPolicy(AccessPolicy policy) {
    _cachedPolicy = policy;
  }

  /// Get current policy safely
  AccessPolicy getPolicy() {
    return _cachedPolicy ?? AccessPolicy.empty();
  }

  /// Check if policy is loaded
  bool get isReady => _cachedPolicy != null;

  /// Clear cache (useful for logout / tenant switch)
  void clear() {
    _cachedPolicy = null;
  }
}