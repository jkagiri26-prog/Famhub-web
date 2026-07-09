import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

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
  // Use centralized SupabaseService instead of direct Supabase.instance.client
  final SupabaseClient _client = SupabaseService.instance.client;

  List<SystemModule>? _cache;

  // ── Cache TTL (Time-To-Live) Configuration ──
  // After this duration, the cache is considered stale
  // and will be refreshed on the next getActiveModules() call.
  static const Duration _cacheTtl = Duration(minutes: 5);

  // Timestamp when the cache was last populated
  DateTime? _cacheTimestamp;

  /// Whether the cache is considered fresh based on TTL
  bool get _isCacheFresh {
    if (_cache == null || _cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheTtl;
  }

  /// 🚀 PUBLIC ENTRY: Get active modules
  Future<List<SystemModule>> getActiveModules() async {
    // Cache hit: only return cached data if within TTL window
    if (_cache != null && _isCacheFresh) {
        return _cache!;
      }

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
        _cacheTimestamp = DateTime.now();
        return _cache!;
      }

      _cache = response
          .map<SystemModule>(
              (m) => SystemModule.fromMap(m))
          .toList();
      _cacheTimestamp = DateTime.now();
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
          _cacheTimestamp = DateTime.now();
          debugPrint(
              '[FALLBACK] Parsed ${_cache!.length} SystemModule instances');
          return _cache!;
    }
      } catch (fallbackError) {
        debugPrint('[FALLBACK] Also failed: $fallbackError');
  }

      // If cache is stale but we have data, return stale data as fallback
      if (_cache != null) {
        debugPrint('[MODULE_SERVICE] Returning stale cache as fallback');
        return _cache!;
  }

      rethrow;
    } catch (e, st) {
      debugPrint('MODULE FETCH FAILED');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $st');

      // If cache is stale but we have data, return stale data as fallback
      if (_cache != null) {
        debugPrint('[MODULE_SERVICE] Returning stale cache as fallback');
        return _cache!;
}

      rethrow;
    }
  }

  /// 🔄 Manual refresh (admin, feature flags, etc.)
  Future<List<SystemModule>> refreshModules() async {
    _cache = null;
    _cacheTimestamp = null;
    return getActiveModules();
  }

  /// ⏰ Force cache expiry — next getActiveModules() will fetch fresh data
  void invalidateCache() {
    _cacheTimestamp = null;
    // Keep _cache for fallback purposes but mark as stale
    debugPrint('[MODULE_SERVICE] Cache invalidated — next fetch will refresh');
  }
}
