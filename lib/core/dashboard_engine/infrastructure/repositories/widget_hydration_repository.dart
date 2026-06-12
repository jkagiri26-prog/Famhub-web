import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/dashboard_engine/domain/models/widget_state_model.dart';

class WidgetHydrationRepository {
  WidgetHydrationRepository(this.client);

  final SupabaseClient client;

  /// SAVE STATE
  Future<void> save(WidgetStateModel state) async {
    await client.from('widget_states').upsert({
      'widget_id': state.widgetId,
      'state': state.state,
      'updated_at': (state.lastUpdated ?? DateTime.now()).toIso8601String(),
    });
  }

  /// LOAD ALL STATES
  Future<List<WidgetStateModel>> loadAll() async {
    final data = await client
        .from('widget_states')
        .select();

    return (data as List).map((e) {
      return WidgetStateModel(
        widgetId: e['widget_id'],
        state: Map<String, dynamic>.from(e['state']),
        lastUpdated: DateTime.parse(e['updated_at']),
      );
    }).toList();
  }
}