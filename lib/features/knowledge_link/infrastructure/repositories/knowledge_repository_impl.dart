/// ============================================================
/// KNOWLEDGE REPOSITORY IMPLEMENTATION (SUPABASE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/infrastructure/repositories/
///
/// Wires Knowledge Link to:
///   - `public.resolve_knowledge_resources(...)`  — the canonical resolver
///     (matching algorithm lives in Postgres, NOT here).
///   - `knowledge.resource_versions` / `knowledge.sections` /
///     `knowledge.content_blocks` — to load a published resource detail.
///
/// Only published versions are ever read. Draft/review/approved versions are
/// never surfaced to the UI.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_context.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';
import 'package:famhub_app/features/knowledge_link/domain/repositories/knowledge_repository.dart';

class KnowledgeRepositoryImpl implements KnowledgeRepository {
  KnowledgeRepositoryImpl();

  final SupabaseService _service = SupabaseService.instance;

  /// The resolver lives in the default `public` schema.
  SupabaseClient get _client => _service.client;

  @override
  Future<List<KnowledgeResourceMatch>> resolveResources(
    KnowledgeContext context, {
    int limit = 10,
  }) async {
    // Param names follow the Postgres/snake_case convention used by the
    // `knowledge` schema columns (item_id, variant_id, …). The resolver is
    // `public.resolve_knowledge_resources` — verify these names match the
    // deployed function signature if the backend ever renames them.
    try {
      final response = await _client.rpc('resolve_knowledge_resources', params: {
        if (context.itemId != null) 'item_id': context.itemId,
        if (context.variantId != null) 'variant_id': context.variantId,
        if (context.commodityId != null) 'commodity_id': context.commodityId,
        if (context.activityTypeId != null)
          'activity_type_id': context.activityTypeId,
        if (context.locationId != null) 'location_id': context.locationId,
        if (context.resourceTypeCode != null)
          'resource_type_code': context.resourceTypeCode,
        'limit': limit,
      });

      if (response == null) return const [];
      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) =>
                KnowledgeResourceMatch.fromMap(Map<String, dynamic>.from(row)))
            .toList();
      }
      return const [];
    } on PostgrestException catch (e) {
      throw KnowledgeException('Failed to resolve knowledge resources: ${e.message}');
    } catch (e) {
      throw KnowledgeException('Failed to resolve knowledge resources: $e');
    }
  }

  @override
  Future<KnowledgeResourceDetail?> getResourceDetail(
    String resourceId, {
    String? publishedVersionId,
  }) async {
    try {
      final resource = await _fetchResource(resourceId);
      if (resource == null) return null;

      var versionId = publishedVersionId;
      var versionNumber = 0;
      if (versionId == null || versionId.isEmpty) {
        final version = await _fetchPublishedVersion(resourceId);
        if (version == null) return null;
        versionId = version['id']?.toString();
        versionNumber = (version['version_number'] as num?)?.toInt() ?? 0;
      } else {
        final version = await _fetchVersion(versionId);
        if (version == null) return null;
        versionNumber = (version['version_number'] as num?)?.toInt() ?? 0;
      }

      if (versionId == null || versionId.isEmpty) return null;

      final sections = await _fetchSections(versionId);

      return KnowledgeResourceDetail(
        resourceId: resourceId,
        versionId: versionId,
        versionNumber: versionNumber,
        title: resource['title']?.toString() ?? '',
        summary: resource['summary']?.toString(),
        resourceTypeCode: resource['resource_type_code']?.toString(),
        resourceTypeName: resource['resource_type_name']?.toString(),
        sections: sections,
      );
    } on PostgrestException catch (e) {
      throw KnowledgeException('Failed to load knowledge resource: ${e.message}');
    } catch (e) {
      throw KnowledgeException('Failed to load knowledge resource: $e');
    }
  }

  // ── Private loaders ──

  Future<Map<String, dynamic>?> _fetchResource(String resourceId) async {
    final rows = await _service
        .from('resources', schema: 'knowledge')
        .select('id, title, summary, resource_type_id')
        .eq('id', resourceId)
        .maybeSingle();
    if (rows == null) return null;
    final map = Map<String, dynamic>.from(rows);

    // Resolve the resource type label when available.
    final typeId = map['resource_type_id']?.toString();
    if (typeId != null && typeId.isNotEmpty) {
      try {
        final typeRow = await _service
            .from('resource_types', schema: 'knowledge')
            .select('code, name')
            .eq('id', typeId)
            .maybeSingle();
        if (typeRow != null) {
          map['resource_type_code'] = typeRow['code']?.toString();
          map['resource_type_name'] = typeRow['name']?.toString();
        }
      } catch (_) {
        // Type label is display-only; ignore when unavailable.
      }
    }
    return map;
  }

  Future<Map<String, dynamic>?> _fetchPublishedVersion(String resourceId) async {
    final rows = await _service
        .from('resource_versions', schema: 'knowledge')
        .select('id, version_number, status')
        .eq('resource_id', resourceId)
        .eq('status', 'published')
        .order('version_number', ascending: false)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return list.first;
  }

  Future<Map<String, dynamic>?> _fetchVersion(String versionId) async {
    final row = await _service
        .from('resource_versions', schema: 'knowledge')
        .select('id, version_number, status')
        .eq('id', versionId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<KnowledgeSection>> _fetchSections(String versionId) async {
    final sectionRows = await _service
        .from('sections', schema: 'knowledge')
        .select('id, title, section_order, summary')
        .eq('resource_version_id', versionId)
        .eq('is_active', true)
        .order('section_order', ascending: true);
    final sections = (sectionRows as List).cast<Map<String, dynamic>>();

    if (sections.isEmpty) return const [];

    final sectionIds = sections.map((s) => s['id']?.toString() ?? '').toList();
    final blockRows = await _service
        .from('content_blocks', schema: 'knowledge')
        .select('id, section_id, block_type, block_order, content')
        .inFilter('section_id', sectionIds)
        .order('block_order', ascending: true);
    final blocks = (blockRows as List).cast<Map<String, dynamic>>();

    final blocksBySection = <String, List<KnowledgeContentBlock>>{};
    for (final b in blocks) {
      final sectionId = b['section_id']?.toString() ?? '';
      blocksBySection.putIfAbsent(sectionId, () => []).add(
            KnowledgeContentBlock(
              id: b['id']?.toString() ?? '',
              blockType: b['block_type']?.toString() ?? '',
              blockOrder: (b['block_order'] as num?)?.toInt() ?? 0,
              content: b['content'] is Map
                  ? Map<String, dynamic>.from(b['content'] as Map)
                  : const {},
            ),
          );
    }

    return sections.map((s) {
      final id = s['id']?.toString() ?? '';
      return KnowledgeSection(
        id: id,
        title: s['title']?.toString() ?? '',
        sectionOrder: (s['section_order'] as num?)?.toInt() ?? 0,
        summary: s['summary']?.toString(),
        blocks: blocksBySection[id] ?? const [],
      );
    }).toList();
  }
}

class KnowledgeException implements Exception {
  final String message;

  KnowledgeException(this.message);

  @override
  String toString() => message;
}
