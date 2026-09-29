/// ============================================================
/// AGRI CONNECT — POST / REPLY TILE
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/reaction_summary.dart';
import '../../application/providers/discussion_provider.dart';
import '../format.dart';
import 'reaction_bar.dart';

class PostTile extends ConsumerWidget {
  final Post post;
  final bool canReply;
  final VoidCallback? onReply;
  final VoidCallback? onReport;

  const PostTile({
    super.key,
    required this.post,
    this.canReply = false,
    this.onReply,
    this.onReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (post.isDeleted) {
      return _deleted(context);
    }

    final reactionsAsync = ref.watch(postReactionsProvider(post.id));
    final summary = reactionsAsync.value ?? const ReactionSummary();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  _initial(post.authorName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName ?? 'Farmer',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${agriTimeAgo(post.createdAt)}'
                      '${post.isEdited ? ' · edited' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReport != null)
                IconButton(
                  onPressed: onReport,
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  tooltip: 'Report',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ReactionBar(
                  summary: summary,
                  onReact: (emoji) => ref
                      .read(discussionControllerProvider.notifier)
                      .react(postId: post.id, reaction: emoji),
                  onRemove: () => ref
                      .read(discussionControllerProvider.notifier)
                      .removeReaction(post.id),
                ),
              ),
              if (canReply && onReply != null)
                InkWell(
                  onTap: onReply,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply_outlined,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deleted(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'This post was deleted.',
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return 'F';
    return name[0].toUpperCase();
  }
}
