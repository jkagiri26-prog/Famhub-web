/// ============================================================
/// AGRI CONNECT — MESSAGES TAB
/// ============================================================
///
/// The user's conversations (direct, group, community, …).
/// Chat stays separate from the public discussion forum.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/messaging_provider.dart';
import '../widgets/conversation_tile.dart';
import 'conversation_page.dart';
import 'new_conversation_page.dart';

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load messages.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(conversationsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 40,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text('No messages yet.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewConversationPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Start a conversation'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = conversations[index];
            return ConversationTile(
              conversation: c,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConversationPage(conversationId: c.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
