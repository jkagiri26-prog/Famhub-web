import 'package:supabase_flutter/supabase_flutter.dart';

class ModuleRealtimeListener {
  ModuleRealtimeListener(this.supabase);

  final SupabaseClient supabase;

  RealtimeChannel createChannel({
    required String channelName,
  }) {
    return supabase.channel(channelName);
  }
}