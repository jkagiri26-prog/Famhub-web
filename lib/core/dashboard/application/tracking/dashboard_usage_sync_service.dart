import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardUsageSyncService {
  final SupabaseClient client;

  DashboardUsageSyncService(this.client);

  Future<void> syncEvent({
    required String widgetKey,
    required String eventType,
    String? moduleKey,
    String? entityId,
  }) async {
    try {
      await client.from('analytics_events').insert({
        'event_type': eventType,
        'module_name': moduleKey ?? 'dashboard',
        'entity_id': entityId,
        'payload': {
          'widget_key': widgetKey,
          'source': 'dashboard_usage_tracker',
        },
      });
    } catch (_) {
      /// never block UI due to analytics failure
    }
  }
}