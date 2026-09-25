/// ============================================================
/// KNOWLEDGE LINK PROVIDERS (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/application/providers/
///
/// Riverpod state management for contextual knowledge resolution and guide
/// detail loading. The resolver repository is the ONLY data source — no
/// client-side matching, no hard-coded guides.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_context.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';
import 'package:famhub_app/features/knowledge_link/domain/repositories/knowledge_repository.dart';
import 'package:famhub_app/features/knowledge_link/infrastructure/repositories/knowledge_repository_impl.dart';

/// The Knowledge repository implementation (single instance).
final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepositoryImpl();
});

/// Resolves curated guides for a canonical [KnowledgeContext].
///
/// Returns a [ContextualKnowledgeData] envelope so the future Agri Connect
/// discussion surface can eventually be served from the SAME context.
/// `discussions` is always empty today.
final contextualKnowledgeProvider = FutureProvider.family<
    ContextualKnowledgeData, KnowledgeContext>((ref, context) async {
  if (context.isEmpty) {
    return const ContextualKnowledgeData();
  }
  final repository = ref.watch(knowledgeRepositoryProvider);
  final guides = await repository.resolveResources(context);
  return ContextualKnowledgeData(guides: guides);
});

/// Loads the published resource/version detail for the guide screen.
final knowledgeResourceDetailProvider = FutureProvider.family<
    KnowledgeResourceDetail?,
    KnowledgeResourceDetailParams>((ref, params) async {
  final repository = ref.watch(knowledgeRepositoryProvider);
  return repository.getResourceDetail(
    params.resourceId,
    publishedVersionId: params.publishedVersionId,
  );
});

/// Parameters for loading a guide detail (resource + optional version id).
class KnowledgeResourceDetailParams {
  final String resourceId;
  final String? publishedVersionId;

  const KnowledgeResourceDetailParams({
    required this.resourceId,
    this.publishedVersionId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeResourceDetailParams &&
          resourceId == other.resourceId &&
          publishedVersionId == other.publishedVersionId;

  @override
  int get hashCode => Object.hash(resourceId, publishedVersionId);
}
