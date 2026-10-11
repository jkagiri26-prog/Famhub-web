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

  /// Called when the author taps Edit.
  final VoidCallback? onEdit;

  /// The author's profile id, used to gate the Edit action.
  final String? authorProfileId;

  const PostTile({
    super.key,
    required this.post,
    this.canReply = false,
    this.onReply,
    this.onReport,
    this.onEdit,
    this.authorProfileId,
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
        const SizedBox(width: 9),
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
              const SizedBox(height: 3),
              Text(
                post.body,
                style: TextStyle(fontSize: 14, height: 1.45, color: bodyCol),
              ),
              _images(context, ref, cs),
              const SizedBox(height: 3),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
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
                  if (onEdit != null &&
                      authorProfileId != null &&
                      authorProfileId == post.authorProfileId)
                    IconButton(
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: cs.outline,
                      ),
                      tooltip: 'Edit',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Attached comment images (0–2) resolved through `media_get_by_context`
  /// (context `agri_connect_post`, keyed by this post's id). Mirrors the
  /// discussion-image conventions: bounded loading state, tap-to-retry on
  /// lookup failures and per-image error tiles for expired URLs — display
  /// never depends on persisted post metadata.
  Widget _images(BuildContext context, WidgetRef ref, ColorScheme cs) {
    final urlsAsync = ref.watch(postMediaUrlsProvider(post.id));
    final urls = (urlsAsync.value ?? const <String>[]).take(2).toList();
    if (urls.isEmpty) {
      if (urlsAsync.isLoading) {
        return const Padding(
          padding: EdgeInsets.only(top: 4),
          child: SizedBox(
            height: 72,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      }
      if (!urlsAsync.hasError) {
        // No attachments for this comment — no extra chrome.
        return const SizedBox.shrink();
      }
      return GestureDetector(
        onTap: () => ref.invalidate(postMediaUrlsProvider(post.id)),
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(top: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Image unavailable. Tap to retry.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: cs.outline),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          for (var i = 0; i < urls.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == urls.length - 1 ? 0 : 8),
                child: _imageTile(urls[i], ref, cs),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageTile(String url, WidgetRef ref, ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        // A failed/expired URL re-signs by re-running the urls provider.
        onTap: () => ref.invalidate(postMediaUrlsProvider(post.id)),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 160,
              color: cs.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            height: 160,
            color: cs.surfaceContainerHighest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 24, color: cs.outline),
                const SizedBox(height: 4),
                Text(
                  'Tap to retry',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
            ),
          ),
        ),
      ),
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
