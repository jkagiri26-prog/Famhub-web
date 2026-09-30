/// ============================================================
/// AGRI CONNECT — DISCUSSIONS LIST PAGE
/// ============================================================
///
/// Also used embedded inside the community shell (set `embedded: true` to
/// skip the Scaffold/AppBar and render the list directly).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/discussion_provider.dart';
import '../widgets/discussion_card.dart';
import 'discussion_details_page.dart';
import 'create_discussion_page.dart';

class DiscussionsPage extends ConsumerWidget {
  final String? communityId;
  final bool embedded;

  const DiscussionsPage({super.key, this.communityId, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _content(context, ref);

    if (embedded) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Discussions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (communityId != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New discussion',
              onPressed: () => _openCreate(context),
            ),
        ],
      ),
      body: content,
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final discussionsAsync = ref.watch(discussionsProvider(communityId));

    return discussionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load discussions.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(discussionsProvider(communityId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (discussions) {
        if (discussions.isEmpty) {
          return _emptyState(context);
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: discussions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final d = discussions[index];
            return DiscussionCard(
              discussion: d,
              onTap: () => _openDiscussion(context, d.id),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No discussions yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a question or start a farming topic for this community.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (communityId != null)
            OutlinedButton.icon(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add),
              label: const Text('Start a discussion'),
            ),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context) {
    if (communityId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateDiscussionPage(communityId: communityId!),
      ),
    );
  }

  void _openDiscussion(BuildContext context, String discussionId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionDetailsPage(discussionId: discussionId),
      ),
    );
  }
}
