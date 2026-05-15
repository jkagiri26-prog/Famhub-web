import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/dashboard_descriptor.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../services/dashboard_cache_store.dart';

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    Supabase.instance.client,
    DashboardCacheStore(),
  );
});

class DashboardRepositoryImpl implements DashboardRepository {
  final SupabaseClient supabase;
  final DashboardCacheStore cache;

  DashboardRepositoryImpl(
    this.supabase,
    this.cache,
  );

  // ============================================================
  // STREAM (clean + deterministic)
  // ============================================================
  @override
  Stream<List<DashboardDescriptor>> watchDescriptors(
    String moduleKey,
  ) {
    final stream = supabase
        .from('dashboard_descriptors')
        .stream(primaryKey: ['id'])
        .eq('module_key', moduleKey)
        .order('priority', ascending: false)
        .order('display_order', ascending: true)
        .map(_mapRows)
        .map(_applyRules);

    // cache warm start (non-blocking)
    final cached = cache.get(moduleKey);

    if (cached != null) {
      return stream.transform(
        StreamTransformer.fromHandlers(
          handleListen: (sink) {
            sink.add(cached);
          },
          handleData: (data, sink) {
            sink.add(data);
          },
        ),
      );
    }

    return stream;
  }

  // ============================================================
  // FETCH
  // ============================================================
  @override
  Future<List<DashboardDescriptor>> getDescriptors(
    String moduleKey,
  ) async {
    final response = await supabase
        .from('dashboard_descriptors')
        .select()
        .eq('module_key', moduleKey)
        .order('priority', ascending: false)
        .order('display_order', ascending: true);

    final descriptors =
        _mapRows(response).where((e) => e.isEnabled).toList();

    cache.set(moduleKey, descriptors);

    return descriptors;
  }

  // ============================================================
  // SINGLE SOURCE OF TRUTH MAPPING
  // ============================================================
  List<DashboardDescriptor> _mapRows(dynamic rows) {
    return (rows as List)
        .map((e) => DashboardDescriptor.fromMap(e))
        .toList();
  }

  // ============================================================
  // BUSINESS RULES (centralized)
  // ============================================================
  List<DashboardDescriptor> _applyRules(
    List<DashboardDescriptor> list,
  ) {
    return list.where((e) => e.isEnabled).toList();
  }
}