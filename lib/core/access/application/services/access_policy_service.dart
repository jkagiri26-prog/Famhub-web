import '../../domain/models/access_policy.dart';

class AccessPolicyService {
  AccessPolicy? _cachedPolicy;

  void setPolicy(AccessPolicy policy) {
    _cachedPolicy = policy;
  }

  AccessPolicy getPolicy() {
    return _cachedPolicy ?? AccessPolicy.empty();
  }

  bool get isReady => _cachedPolicy != null;

  void clear() {
    _cachedPolicy = null;
  }
}