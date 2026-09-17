import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/access/domain/models/access_policy.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

class AccessPolicyRepository {
  AccessPolicyRepository({
    SupabaseService? supabaseService,
  }) : _supabaseService =
            supabaseService ?? SupabaseService.instance;

  final SupabaseService _supabaseService;

  /// Authoritative permission check.
  ///
  /// Calls the canonical backend function `core.has_permission(p_permission)`,
  /// which resolves the result from the authenticated user's ACTIVE
  /// entity-context session, role permissions, entity scopes and permission
  /// overrides. Nothing is granted client-side.
  ///
  /// The call is never made without an authenticated Supabase session
  /// (never with the anon key). On a 401/403 auth failure the session is
  /// refreshed once and the call retried; if the session cannot be
  /// recovered it is cleared so the app returns to login instead of
  /// retrying with a stale token.
  Future<bool> hasPermission(String permission) async {
    if (_supabaseService.currentSession == null) {
      throw AccessPolicyRepositoryException(
        'No authenticated session for permission "$permission"',
      );
    }

    try {
      return await _callHasPermission(permission);
    } on PostgrestException catch (e) {
      if (_isAuthFailure(e)) {
        final refreshed = await _supabaseService.refreshSessionSafely();
        if (refreshed) return _callHasPermission(permission);
      }
      throw AccessPolicyRepositoryException(
        'Failed to resolve permission "$permission": ${e.message}',
      );
    } on AuthException catch (e) {
      final refreshed = await _supabaseService.refreshSessionSafely();
      if (refreshed) return _callHasPermission(permission);
      throw AccessPolicyRepositoryException(
        'Failed to resolve permission "$permission": ${e.message}',
      );
    } catch (e) {
      throw AccessPolicyRepositoryException(
        'Failed to resolve permission "$permission": $e',
      );
    }
  }

  Future<bool> _callHasPermission(String permission) async {
    final response = await _supabaseService.client
        .schema('core')
        .rpc('has_permission', params: {'p_permission': permission});

    if (response is bool) return response;
    if (response is Map) {
      final value = response['has_permission'] ??
          response['allowed'] ??
          response['result'];
      return value == true;
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is bool) return first;
      if (first is Map) {
        final value = first['has_permission'] ??
            first['allowed'] ??
            first['result'];
        return value == true;
      }
    }
    return false;
  }

  bool _isAuthFailure(PostgrestException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    return code == 'PGRST301' ||
        code == 'PGRST302' ||
        message.contains('jwt') ||
        message.contains('sub claim') ||
        message.contains('permission denied') ||
        message.contains('unauthorized');
  }

  Future<AccessPolicy> fetchPolicy() async {
    try {
      final response = await _supabaseService.rpc(
        'get_access_policy',
      );

      if (response == null ||
          response is! Map<String, dynamic>) {
        return AccessPolicy.empty();
      }

      final rolePermissionsRaw =
          response['role_permissions']
                  as Map<String, dynamic>? ??
              {};

      final featureTiersRaw =
          response['feature_tiers']
                  as Map<String, dynamic>? ??
              {};

      final rolePermissions =
          rolePermissionsRaw.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(
            (value as List?) ?? const [],
          ),
        ),
      );

      final featureTiers =
          featureTiersRaw.map(
        (key, value) {
          final tierString =
              value?.toString().toLowerCase();

          final tier =
              SubscriptionTier.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                tierString,
            orElse: () =>
                SubscriptionTier.free,
          );

          return MapEntry(key, tier);
        },
      );

      return AccessPolicy(
        rolePermissions: rolePermissions,
        featureTiers: featureTiers,
      );
    } catch (e) {
      throw AccessPolicyRepositoryException(
        'Failed to fetch access policy: $e',
      );
    }
  }
}

class AccessPolicyRepositoryException
    implements Exception {
  AccessPolicyRepositoryException(this.message);

  final String message;

  @override
  String toString() {
    return 'AccessPolicyRepositoryException: $message';
  }
}