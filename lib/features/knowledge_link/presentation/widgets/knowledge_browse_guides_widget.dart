/// ============================================================
/// KNOWLEDGE BROWSE GUIDES WIDGET
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/presentation/widgets/
///
/// The Knowledge Link landing-page guide list, backed by the backend
/// resolver (no module context). Replaces the previous hard-coded demo
/// "Reading List". Shows loading / empty / error / list states.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

import 'package:famhub_app/features/knowledge_link/application/providers/knowledge_providers.dart';
import 'package:famhub_app/features/knowledge_link/presentation/widgets/knowledge_guide_tile_widget.dart';

class KnowledgeBrowseGuidesWidget extends ConsumerWidget {
  const KnowledgeBrowseGuidesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidesAsync = ref.watch(knowledgeBrowseGuidesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeaderWidget(title: 'Guides'),
        const SizedBox(height: 12),
        guidesAsync.when(
          loading: () => const _BrowseSkeleton(),
          error: (err, _) => _BrowseError(
            onRetry: () => ref.invalidate(knowledgeBrowseGuidesProvider),
          ),
          data: (guides) {
            if (guides.isEmpty) {
              return Text(
                'No guides available yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              );
            }
            return Column(
              children: [
                for (final guide in guides) ...[
                  KnowledgeGuideTileWidget(guide: guide),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BrowseSkeleton extends StatelessWidget {
  const _BrowseSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) {
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

class _BrowseError extends StatelessWidget {
  final VoidCallback onRetry;

  const _BrowseError({required this.onRetry});

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
