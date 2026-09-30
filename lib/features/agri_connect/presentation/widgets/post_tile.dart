/// ============================================================
/// AGRI CONNECT — POST / REPLY TILE
/// ============================================================
///
/// Flat Facebook-style row (no card border of its own) so the post,
/// comments and replies read as one continuous thread. Colors distinguish
/// comment vs reply text.
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

  /// Name / avatar colour for this row.
  final Color? accent;

  /// Body text colour for this row.
  final Color? bodyColor;

  /// Replies render smaller and indented under their comment.
  final bool nested;

  const PostTile({
    super.key,
    required this.post,
    this.canReply = false,
    this.onReply,
    this.onReport,
    this.accent,
    this.bodyColor,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (post.isDeleted) {
      return _deleted(context);
    }

    final reactionsAsync = ref.watch(postReactionsProvider(post.id));
    final summary = reactionsAsync.value ?? const ReactionSummary();

    final cs = Theme.of(context).colorScheme;
    final accentColor = accent ?? cs.primary;
    final bodyCol = bodyColor ?? cs.onSurface;
    final radius = nested ? 13.0 : 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: accentColor.withValues(alpha: 0.12),
          child: Text(
            _initial(post.authorName),
            style: TextStyle(
              fontSize: nested ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.authorName ?? 'Farmer',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${agriTimeAgo(post.createdAt)}'
                    '${post.isEdited ? ' · edited' : ''}',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                post.body,
                style: TextStyle(fontSize: 14, height: 1.45, color: bodyCol),
              ),
              const SizedBox(height: 6),
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
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (onReport != null)
                    IconButton(
                      onPressed: onReport,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: cs.outline,
                      ),
                      tooltip: 'Report',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deleted(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.block, size: 14, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This post was deleted.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return 'F';
    return name[0].toUpperCase();
  }
}
