/// ============================================================
/// KNOWLEDGE GUIDE TILE WIDGET (SHARED)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/presentation/widgets/
///
/// A compact, tappable guide row used by the contextual Knowledge surface
/// and the Knowledge Link landing page. Tapping opens the guide reader.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_resource_detail_page.dart';

class KnowledgeGuideTileWidget extends StatelessWidget {
  final KnowledgeResourceMatch guide;

  const KnowledgeGuideTileWidget({super.key, required this.guide});

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
