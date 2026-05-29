import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/widget_hydrated_state.dart';

class WidgetHydrationRepository {
  WidgetHydrationRepository(this.client);

  final SupabaseClient client;

  /// SAVE STATE
  Future<void> save(WidgetHydratedState state) async {
    await client.from('widget_states').upsert({
      'widget_id': state.widgetId,
      'state': state.state,
      'updated_at': state.updatedAt.toIso8601String(),
    });
  }

  /// LOAD ALL STATES
  Future<List<WidgetHydratedState>> loadAll() async {
    final data = await client
        .from('widget_states')
        .select();

    return (data as List).map((e) {
      return WidgetHydratedState(
        widgetId: e['widget_id'],
        state: Map<String, dynamic>.from(e['state']),
        updatedAt: DateTime.parse(e['updated_at']),
      );
    }).toList();
  }
}