/// ============================================================
/// AGRI CONNECT — DISCUSSION DETAILS PAGE
/// ============================================================
///
/// Records a valid view event on open (backend maintains view_count).
/// Shows posts/replies, reactions, reply composer and report action.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/discussion.dart';
import '../../domain/entities/post.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../domain/enums/safety_enums.dart';
import '../../application/providers/discussion_provider.dart';
import '../../application/providers/agri_connect_providers.dart';
import '../../application/providers/community_provider.dart';
import '../format.dart';
import '../widgets/post_tile.dart';
import '../widgets/report_sheet.dart';

class DiscussionDetailsPage extends ConsumerStatefulWidget {
  final String discussionId;

  const DiscussionDetailsPage({super.key, required this.discussionId});

  @override
  ConsumerState<DiscussionDetailsPage> createState() =>
      _DiscussionDetailsPageState();
}

class _DiscussionDetailsPageState extends ConsumerState<DiscussionDetailsPage> {
  final _composerController = TextEditingController();
  final _replyController = TextEditingController();
  String? _replyingTo;
  bool _viewRecorded = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordView());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    await ref
        .read(discussionControllerProvider.notifier)
        .recordView(widget.discussionId);
  }

  @override
  Widget build(BuildContext context) {
    final discussionAsync = ref.watch(
      discussionDetailsProvider(widget.discussionId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(discussionAsync.value?.title ?? 'Discussion'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
            onPressed: () => showAgriReportSheet(
              context,
              ref,
              targetType: ReportTargetType.discussion,
              targetId: widget.discussionId,
            ),
          ),
        ],
      ),
      body: discussionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load discussion.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(
                  discussionDetailsProvider(widget.discussionId),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (discussion) {
          if (discussion == null) {
            return const Center(child: Text('Discussion not found.'));
          }
          return _content(context, discussion);
        },
      ),
    );
  }

  Widget _content(BuildContext context, Discussion discussion) {
    final postsAsync = ref.watch(
      postsProvider((discussionId: discussion.id, parentId: null)),
    );
    final canModerate = _canModerate(discussion);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // ── ONE CONTAINER: post + comments + replies ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── The post ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _header(context, discussion, canModerate),
                    ),
                    if (discussion.mediaFileIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _images(context, discussion),
                      ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    // ── Comments + replies ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: postsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Could not load posts.',
                            style: TextStyle(color: cs.outline),
                          ),
                        ),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return _noComments(discussion, cs);
                          }
                          final children = <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.mode_comment_outlined,
                                    size: 14,
                                    color: cs.tertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Comments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ];
                          for (var i = 0; i < posts.length; i++) {
                            if (i > 0) {
                              children.add(
                                Divider(
                                  height: 8,
                                  indent: 30,
                                  endIndent: 2,
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              );
                            }
                            children.add(_post(context, discussion, posts[i]));
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!discussion.isLocked) _composer(context, discussion),
      ],
    );
  }

  Widget _noComments(Discussion discussion, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: cs.tertiary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              discussion.isLocked
                  ? 'This discussion is locked.'
                  : 'No comments yet. Be the first to reply.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Discussion discussion,
    bool canModerate,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                discussion.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  height: 1.3,
                ),
              ),
            ),
            if (discussion.isPinned)
              Icon(Icons.push_pin, size: 16, color: cs.primary),
            if (discussion.isLocked)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.lock_outline, size: 16, color: cs.tertiary),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _tag(discussion.type.label, _typeColor(discussion.type)),
            _tag('${discussion.replyCount} replies', cs.primary),
            _tag('${discussion.viewCount} views', cs.tertiary),
            Text(
              agriTimeAgo(discussion.createdAt),
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
          ],
        ),
        if (canModerate) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _togglePinned(discussion),
                icon: Icon(
                  discussion.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  size: 16,
                ),
                label: Text(discussion.isPinned ? 'Unpin' : 'Pin'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _toggleLocked(discussion),
                icon: Icon(
                  discussion.isLocked
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(discussion.isLocked ? 'Unlock' : 'Lock'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool _canModerate(Discussion discussion) {
    final communityId = discussion.communityId;
    if (communityId == null || communityId.isEmpty) return false;
    final membership = ref.watch(myMembershipProvider(communityId)).value;
    return membership?.role.canModerate ?? false;
  }

  Future<void> _togglePinned(Discussion discussion) async {
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .setPinned(discussionId: discussion.id, pinned: !discussion.isPinned);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update discussion: $e')),
      );
    }
  }

  Future<void> _toggleLocked(Discussion discussion) async {
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .setLocked(discussionId: discussion.id, locked: !discussion.isLocked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update discussion: $e')),
      );
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _post(BuildContext context, Discussion discussion, Post post) {
    final repliesAsync = ref.watch(
      postsProvider((discussionId: discussion.id, parentId: post.id)),
    );
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment — green accent.
        PostTile(
          post: post,
          accent: cs.primary,
          bodyColor: cs.onSurface,
          canReply: !discussion.isLocked,
          onReply: () => setState(() => _replyingTo = post.id),
          onReport: () => showAgriReportSheet(
            context,
            ref,
            targetType: ReportTargetType.post,
            targetId: post.id,
          ),
        ),
        repliesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (replies) {
            if (replies.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reply — indented under the comment, orange accent.
                for (final reply in replies)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 6),
                    child: PostTile(
                      post: reply,
                      nested: true,
                      accent: cs.tertiary,
                      bodyColor: cs.onSurfaceVariant,
                      onReport: () => showAgriReportSheet(
                        context,
                        ref,
                        targetType: ReportTargetType.post,
                        targetId: reply.id,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_replyingTo == post.id)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: _replyComposer(context, discussion, post.id),
          ),
        const SizedBox(height: 2),
      ],
    );
  }

  /// Attached images (1–2) resolved through the existing media edge
  /// functions. Tap to view full-screen. Only rendered when the
  /// discussion's metadata references media files.
  Widget _images(BuildContext context, Discussion discussion) {
    final cs = Theme.of(context).colorScheme;
    final urlsAsync = ref.watch(discussionMediaUrlsProvider(discussion.id));
    final urls = (urlsAsync.value ?? const <String>[]).take(2).toList();
    if (urls.isEmpty) {
      return SizedBox(
        height: 72,
        child: urlsAsync.isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Center(
                child: Text(
                  'Image unavailable.',
                  style: TextStyle(fontSize: 12.5, color: cs.outline),
                ),
              ),
      );
    }
    final height = urls.length > 1 ? 150.0 : 210.0;
    return Row(
      children: [
        for (var i = 0; i < urls.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: _imageTile(context, urls[i], height),
            ),
          ),
      ],
    );
  }

  Widget _imageTile(BuildContext context, String url, double height) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _viewImage(url),
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          cacheWidth: 1080,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: height,
              width: double.infinity,
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
          errorBuilder: (_, __, ___) => Container(
            height: height,
            width: double.infinity,
            color: cs.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              size: 26,
              color: cs.outline,
            ),
          ),
        ),
      ),
    );
  }

  void _viewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          backgroundColor: Colors.black87,
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: size.width - 24,
            height: size.height * 0.7,
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _composer(BuildContext context, Discussion discussion) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composerController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Write a comment…',
                hintStyle: TextStyle(fontSize: 14, color: cs.outline),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending
                ? null
                : () => _submitPost(context, discussion, null),
            style: IconButton.styleFrom(
              backgroundColor: cs.primary.withValues(alpha: 0.10),
              foregroundColor: cs.primary,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _replyComposer(
    BuildContext context,
    Discussion discussion,
    String parentId,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _replyController,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reply…',
              hintStyle: TextStyle(fontSize: 14, color: cs.outline),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: cs.primary.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.send_rounded, size: 20, color: cs.primary),
          onPressed: () => _submitPost(context, discussion, parentId),
          tooltip: 'Send',
        ),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: cs.outline),
          onPressed: () => setState(() => _replyingTo = null),
          tooltip: 'Cancel',
        ),
      ],
    );
  }

  Future<void> _submitPost(
    BuildContext context,
    Discussion discussion,
    String? parentId,
  ) async {
    final isReply = parentId != null;
    final controller = isReply ? _replyController : _composerController;
    final body = controller.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .createPost(
            discussionId: discussion.id,
            parentPostId: parentId,
            body: body,
          );
      controller.clear();
      if (isReply) setState(() => _replyingTo = null);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
