/// ============================================================
/// AGRI CONNECT — DISCUSSION CARD
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/discussion_provider.dart';
import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../format.dart';

class DiscussionCard extends ConsumerWidget {
  final Discussion discussion;
  final String? authorName;
  final String? communityName;
  final VoidCallback? onTap;

  const DiscussionCard({
    super.key,
    required this.discussion,
    this.authorName,
    this.communityName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeColor = _typeColor(discussion.type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.05),
          highlightColor: colorScheme.primary.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discussion.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        discussion.title,
                        style:
                            theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              letterSpacing: -0.2,
                              color: colorScheme.onSurface,
                            ) ??
                            TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: colorScheme.onSurface,
                            ),
                      ),
                    ),
                    if (discussion.isLocked)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _tag(discussion.type.label, typeColor),
                    if (communityName != null && communityName!.isNotEmpty)
                      _tag(communityName!, colorScheme.primary),
                    if (authorName != null && authorName!.isNotEmpty)
                      Text(
                        'By $authorName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    Text(
                      agriTimeAgo(discussion.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (discussion.mediaFileIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _attachmentStrip(context, ref),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _metric(
                      Icons.chat_bubble_outline_rounded,
                      '${discussion.replyCount}',
                      colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _metric(
                      Icons.remove_red_eye_outlined,
                      '${discussion.viewCount}',
                      colorScheme.tertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lightweight thumbnails for attached images (max 2). Only rendered when
  /// the discussion's metadata references media, and the signed URLs are
  /// decoded at thumbnail size (`cacheWidth`) so feeds never load or decode
  /// original-size images.
  Widget _attachmentStrip(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final urlsAsync = ref.watch(discussionMediaUrlsProvider(discussion.id));
    final urls = (urlsAsync.value ?? const <String>[]).take(2).toList();
    final twoUp = urls.length > 1;
    final height = twoUp ? 96.0 : 132.0;
    if (urls.isEmpty) {
      if (urlsAsync.isLoading) {
        return _stripPlaceholder(cs, height, showSpinner: true);
      }
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 0; i < urls.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  urls[i],
                  height: height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: (twoUp ? 480 : 720),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _stripPlaceholder(cs, height, showSpinner: true);
                  },
                  errorBuilder: (_, __, ___) =>
                      _stripPlaceholder(cs, height, showSpinner: false),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stripPlaceholder(
    ColorScheme cs,
    double height, {
    required bool showSpinner,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: showSpinner
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.broken_image_outlined, size: 22, color: cs.outline),
    );
  }

  Color _typeColor(DiscussionType type) {
    switch (type) {
      case DiscussionType.question:
        return const Color(0xFF1D61E7);
      case DiscussionType.announcement:
        return const Color(0xFFD97706);
      case DiscussionType.poll:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF15803D);
    }
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
