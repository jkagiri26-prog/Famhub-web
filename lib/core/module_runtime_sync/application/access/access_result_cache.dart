import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

class AccessResultCache {
  final Map<String, bool> _cache = {};

  String _buildKey({
    required String moduleKey,
    required String role,
    required SubscriptionTier tier,
  }) {
    return '$moduleKey|$role|${tier.name}';
  }

  bool? get({
    required String moduleKey,
    required String role,
    required SubscriptionTier tier,
  }) {
    return _cache[
      _buildKey(
        moduleKey: moduleKey,
        role: role,
        tier: tier,
      )
    ];
  }

  void set({
    required String moduleKey,
    required String role,
    required SubscriptionTier tier,
    required bool allowed,
  }) {
    _cache[
      _buildKey(
        moduleKey: moduleKey,
        role: role,
        tier: tier,
      )
    ] = allowed;
  }

  bool contains({
    required String moduleKey,
    required String role,
    required SubscriptionTier tier,
  }) {
    return _cache.containsKey(
      _buildKey(
        moduleKey: moduleKey,
        role: role,
        tier: tier,
      ),
    );
  }

  void clear() {
    _cache.clear();
  }
}