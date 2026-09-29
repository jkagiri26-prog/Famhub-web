/// ============================================================
/// AGRI CONNECT — DISCUSSIONS LIST PAGE
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

  const DiscussionsPage({super.key, this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discussionsAsync = ref.watch(discussionsProvider(communityId));

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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateDiscussionPage(communityId: communityId!),
                ),
              ),
            ),
        ],
      ),
      body: discussionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load discussions.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(discussionsProvider(communityId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (discussions) {
          if (discussions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text('No discussions in this community.'),
                  const SizedBox(height: 12),
                  if (communityId != null)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateDiscussionPage(communityId: communityId!),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Start a discussion'),
                    ),
                ],
              ),
            );
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DiscussionDetailsPage(discussionId: d.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
