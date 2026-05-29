import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'module_zone_mapping_engine.dart';

class ModuleZoneMappingSyncEngine {
  ModuleZoneMappingSyncEngine({
    required this.supabase,
    required this.mappingEngine,
  });

  final SupabaseClient supabase;
  final ModuleZoneMappingEngine mappingEngine;

  RealtimeChannel? _channel;

  bool _initialized = false;
  bool _disposed = false;

  Timer? _debounceTimer;

  /// ============================================================
  /// BOOTSTRAP REALTIME LISTENER
  /// ============================================================
  Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    await mappingEngine.warmUp();

    _subscribeToChanges();
  }

  /// ============================================================
  /// SUPABASE LISTENER
  /// ============================================================
  void _subscribeToChanges() {
    _channel = supabase.channel('module-zone-mapping-sync');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'system',
          table: 'module_zone_mappings',
          callback: (_) {
            _handleChangeDebounced();
          },
        )
        .subscribe();
  }

  /// ============================================================
  /// DEBOUNCED HANDLER (PREVENT SYNC STORMS)
  /// ============================================================
  void _handleChangeDebounced() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        await _handleChange();
      },
    );
  }

  /// ============================================================
  /// HANDLE UPDATE EVENT
  /// ============================================================
  Future<void> _handleChange() async {
    if (_disposed) return;

    /// 1. RELOAD CACHE (SAFE SINGLE CALL)
    await mappingEngine.warmUp();

    /// 2. NOTIFY RUNTIME (DECOUPLED)
    _notifyRuntime();
  }

  /// ============================================================
  /// RUNTIME NOTIFICATION HOOK
  /// ============================================================
  void _notifyRuntime() {
    MappingSyncEventBus.instance.emit();
  }

  /// ============================================================
  /// DISPOSE SAFELY
  /// ============================================================
  Future<void> dispose() async {
    _disposed = true;

    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
  }
}