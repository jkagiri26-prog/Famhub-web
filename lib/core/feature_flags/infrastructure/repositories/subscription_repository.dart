import 'package:famhub_app/core/services/supabase_service.dart';

/// ============================================================
/// SUBSCRIPTION REPOSITORY (INFRASTRUCTURE LAYER)
/// ============================================================
///
/// Fetches subscription state from backend.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/infrastructure/repositories/
///     = data access layer (correct location)
///
/// Supabase calls are ALLOWED here (infrastructure layer).
/// ============================================================
class SubscriptionRepository {
  const SubscriptionRepository();

  Future<Map<String, dynamic>> fetchSubscriptionState() async {
    final response =
        await SupabaseService.client.rpc('get_subscription_state');

    return Map<String, dynamic>.from(response ?? {});
  }
}