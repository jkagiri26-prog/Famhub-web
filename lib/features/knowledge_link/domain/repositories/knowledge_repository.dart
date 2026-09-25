/// ============================================================
/// KNOWLEDGE REPOSITORY (ABSTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/domain/repositories/
///
/// The single frontend entry point for resolving contextual knowledge
/// resources and loading a published resource/version detail. There is NO
/// client-side matching algorithm — the backend `public.resolve_knowledge_resources`
/// is authoritative.
/// ============================================================
library;

import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_context.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';

abstract class KnowledgeRepository {
  /// Resolve curated resources for a canonical [KnowledgeContext] via the
  /// backend resolver. Returns only resources the resolver returned.
  Future<List<KnowledgeResourceMatch>> resolveResources(
    KnowledgeContext context, {
    int limit = 10,
  });

  /// Load the published resource/version detail (sections + content blocks
  /// in stored order). Never exposes draft/review/approved versions.
  ///
  /// [publishedVersionId] is optional: when provided it is used directly;
  /// otherwise the latest published version for [resourceId] is resolved.
  Future<KnowledgeResourceDetail?> getResourceDetail(
    String resourceId, {
    String? publishedVersionId,
  });
}
