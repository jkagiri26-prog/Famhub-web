/// ============================================================
/// CONTEXTUAL KNOWLEDGE WIDGET (REUSABLE, MODULE-NEUTRAL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/presentation/widgets/
///
/// A compact, reusable surface that resolves and renders curated Knowledge
/// Link guides for a canonical [KnowledgeContext]. It is intentionally
/// module-neutral: it takes a context, and Knowledge Link resolves the
/// content. It never branches on workspace/user type.
///
/// The surface only shows resources returned by the backend resolver.
/// Discussions (Agri Connect) are intentionally not rendered yet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

import 'package:famhub_app/features/knowledge_link/application/providers/knowledge_providers.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_context.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_resource_detail_page.dart';

class ContextualKnowledgeWidget extends ConsumerWidget {
  /// The canonical subject context supplied by the hosting module.
  final KnowledgeContext knowledgeContext;

  /// Optional label describing the subject (e.g. "Maize / DK8031").
  final String? contextLabel;

  const ContextualKnowledgeWidget({
    super.key,
    required KnowledgeContext context,
    this.contextLabel,
  }) : knowledgeContext = context;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (knowledgeContext.isEmpty) {
      return const SizedBox.shrink();
    }

    final knowledgeAsync = ref.watch(contextualKnowledgeProvider(knowledgeContext));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            const SectionHeaderWidget(title: 'Knowledge'),
            const Spacer(),
            if (contextLabel != null && contextLabel!.isNotEmpty)
              Flexible(
                child: Text(
                  contextLabel!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        knowledgeAsync.when(
          loading: () => const _KnowledgeSkeleton(),
          error: (err, _) => _KnowledgeError(
            onRetry: () =>
                ref.invalidate(contextualKnowledgeProvider(knowledgeContext)),
          ),
          data: (data) {
            if (data.guides.isEmpty) {
              return const _KnowledgeEmpty();
            }
            return _KnowledgeGuideList(guides: data.guides);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────

class _KnowledgeSkeleton extends StatelessWidget {
  const _KnowledgeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (_) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _KnowledgeEmpty extends StatelessWidget {
  const _KnowledgeEmpty();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No guides for this context yet.',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
    );
  }
}

class _KnowledgeError extends StatelessWidget {
  final VoidCallback onRetry;

  const _KnowledgeError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          'Could not load guides.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GUIDE LIST (grouped by resource type)
// ─────────────────────────────────────────────────────────────

class _KnowledgeGuideList extends StatelessWidget {
  final List<KnowledgeResourceMatch> guides;

  const _KnowledgeGuideList({required this.guides});

  @override
  Widget build(BuildContext context) {
    // Group in a stable order, preserving resolver order within each group.
    final groups = <String, List<KnowledgeResourceMatch>>{};
    for (final guide in guides) {
      final label = _sectionLabel(guide);
      groups.putIfAbsent(label, () => []).add(guide);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Text(
            entry.key,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          for (final guide in entry.value) ...[
            _GuideTile(guide: guide),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  String _sectionLabel(KnowledgeResourceMatch guide) {
    final name = guide.resourceTypeName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final code = guide.resourceTypeCode;
    if (code != null && code.trim().isNotEmpty) {
      return _humanizeCode(code.trim());
    }
    return 'Guides';
  }

  String _humanizeCode(String code) {
    switch (code.toLowerCase()) {
      case 'quick_guide':
        return 'Quick Guides';
      case 'general_guide':
        return 'General Guides';
      default:
        final words =
            code.replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty);
        final label = words.map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ');
        return label.isEmpty ? 'Guides' : label;
    }
  }
}

class _GuideTile extends StatelessWidget {
  final KnowledgeResourceMatch guide;

  const _GuideTile({required this.guide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.article_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (guide.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    guide.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _openDetail(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('View guide'),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeResourceDetailPage(
          resourceId: guide.resourceId,
          publishedVersionId: guide.publishedVersionId,
        ),
      ),
    );
  }
}
