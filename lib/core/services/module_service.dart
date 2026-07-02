import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE SERVICE (RUNTIME DATA ACCESS LAYER)
/// ============================================================
///
/// Responsibility:
/// - Fetch module data from backend (Supabase)
/// - Transform to domain models
///
/// 🧠 LOCATION CONTEXT:
///   core/services/ = runtime service layer
///
/// ❌ DOES NOT:
///   - Import UI widgets
///   - Return Flutter Widgets
///   - Perform business evaluation
/// ============================================================
class ModuleService {
  final SupabaseClient _client = Supabase.instance.client;

  List<SystemModule>? _cache;

  /// 🚀 PUBLIC ENTRY: Get active modules
  Future<List<SystemModule>> getActiveModules() async {
    if (_cache != null) return _cache!;

    debugPrint('==============================');
    debugPrint('Starting module fetch');
    try {
      debugPrint(
          '[MODULE_SERVICE] Calling schema("system").from("modules").select()...');
      final response = await _client
          .schema('system')
          .from('modules')
          .select();

            debugPrint('SUCCESS');
      debugPrint('Response type: ${response.runtimeType}');
      debugPrint('Rows: ${response.length}');

      if (response.isNotEmpty) {
        debugPrint('First row keys: ${response.first.keys}');
        debugPrint('First row: ${response.first}');
      } else {
        debugPrint(
            'WARNING: Response is empty array — no modules in database');
      }

      // Handle empty response gracefully
      if (response.isEmpty) {
        _cache = [];
        return _cache!;
      }

      _cache = response
          .map<SystemModule>(
              (m) => SystemModule.fromMap(m))
          .toList();
      debugPrint(
          '[MODULE_SERVICE] Parsed ${_cache!.length} SystemModule instances');
      return _cache!;
    } on PostgrestException catch (e) {
      debugPrint('MODULE FETCH FAILED — PostgrestException');
      debugPrint('  code: ${e.code}');
      debugPrint('  message: ${e.message}');
            debugPrint('  details: ${e.details}');
      debugPrint('  hint: ${e.hint}');

      // ── FALLBACK: Try public schema ──
      // PostgREST may not have 'system' in its db-schemas config.
      // If modules also exist (or are queried) in public schema, try that.
      try {
        debugPrint('[FALLBACK] Trying public schema...');
        final fallbackResponse =
            await _client.from('modules').select();
        debugPrint(
            '[FALLBACK] Public schema returned ${fallbackResponse.length} rows');
                if (fallbackResponse.isNotEmpty) {
          debugPrint('[FALLBACK] First row keys: ${fallbackResponse.first.keys}');
          _cache = fallbackResponse
              .map<SystemModule>((m) => SystemModule.fromMap(m))
              .toList();
          debugPrint(
              '[FALLBACK] Parsed ${_cache!.length} SystemModule instances');
          return _cache!;
        }
      } catch (fallbackError) {
        debugPrint('[FALLBACK] Also failed: $fallbackError');
      }

      rethrow;
    } catch (e, st) {
      debugPrint('MODULE FETCH FAILED');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  /// 🔄 Manual refresh (admin, feature flags, etc.)
  Future<List<SystemModule>> refreshModules() async {
    _cache = null;
    return getActiveModules();
  }
}