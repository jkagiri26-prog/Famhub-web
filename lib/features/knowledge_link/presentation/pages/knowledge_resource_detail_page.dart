/// ============================================================
/// KNOWLEDGE RESOURCE DETAIL PAGE (GUIDE READER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/presentation/pages/
///
/// Read-only viewer for a single published Knowledge resource/version.
/// Loads the selected published version and renders its sections and
/// content blocks in their stored order.
///
/// ❌ Does NOT:
///   - Expose draft/review/approved versions
///   - Offer authoring/editing UI
///   - Re-implement resolver logic
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';

import 'package:famhub_app/features/knowledge_link/application/providers/knowledge_providers.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_resource.dart';

/// A pushed (shell-hosted) guide reader for a resolved resource.
class KnowledgeResourceDetailPage extends ConsumerWidget {
  final String resourceId;

  /// Optional published version id (from the resolver). When null, the
  /// latest published version is resolved.
  final String? publishedVersionId;

  const KnowledgeResourceDetailPage({
    super.key,
    required this.resourceId,
    this.publishedVersionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(knowledgeResourceDetailProvider(
      KnowledgeResourceDetailParams(
        resourceId: resourceId,
        publishedVersionId: publishedVersionId,
      ),
    ));

    return ResponsiveWrapper(
      child: detailAsync.when(
        loading: () => const LoadingStateWidget(
          message: 'Loading guide…',
          useSkeleton: true,
        ),
        error: (err, _) => ErrorStateWidget(
          title: 'Could not load guide',
          message: err.toString(),
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(knowledgeResourceDetailProvider(
            KnowledgeResourceDetailParams(
              resourceId: resourceId,
              publishedVersionId: publishedVersionId,
            ),
          )),
        ),
        data: (detail) {
          if (detail == null) {
            return const EmptyStateWidget(
              icon: Icons.menu_book_outlined,
              title: 'Guide unavailable',
              subtitle: 'This guide is not published yet.',
            );
          }
          return _GuideReader(detail: detail);
        },
      ),
    );
  }
}

class _GuideReader extends StatelessWidget {
  final KnowledgeResourceDetail detail;

  const _GuideReader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
          ),
        ),

        const SizedBox(height: 4),

        ModuleHeaderWidget(
          title: detail.title,
          subtitle: _headerSubtitle(),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              if (detail.summary != null && detail.summary!.isNotEmpty) ...[
                Text(
                  detail.summary!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              for (final section in detail.sections) ...[
                _SectionView(section: section),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _headerSubtitle() {
    final parts = <String>[
      if (detail.resourceTypeName != null &&
          detail.resourceTypeName!.isNotEmpty)
        detail.resourceTypeName!,
      'Version ${detail.versionNumber}',
    ];
    return parts.join(' · ');
  }
}

class _SectionView extends StatelessWidget {
  final KnowledgeSection section;

  const _SectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (section.summary != null && section.summary!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            section.summary!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (final block in section.blocks) ...[
          _BlockView(block: block),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  final KnowledgeContentBlock block;

  const _BlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = block.blockType.trim().toLowerCase();

    if (type == 'heading' || type == 'subheading' || type == 'title') {
      return Text(
        block.text ?? '',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (type == 'quote') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Colors.grey, width: 3)),
        ),
        child: Text(
          block.text ?? '',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    final items = _listItems(block);
    if (items.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final text = block.text;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }

  List<String> _listItems(KnowledgeContentBlock block) {
    final value = block.content['items'] ?? block.content['list'];
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }
}
