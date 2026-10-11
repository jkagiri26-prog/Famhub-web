/// ============================================================
/// AGRI CONNECT — DISCUSSION DETAILS PAGE
/// ============================================================
///
/// Records a valid view event on open (backend maintains view_count).
/// Shows posts/replies, reactions, reply composer and report action.
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../marketplace/infrastructure/services/listing_image_processing.dart';
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
import 'edit_discussion_dialog.dart';

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

  /// Picked (and shared-pipeline WebP-encoded) comment image awaiting send
  /// — preview only; nothing uploads until the send button.
  Uint8List? _composerImage;
  Uint8List? _replyImage;
  bool _pickingImage = false;

  /// Post id + kept bytes when an image upload failed after the comment
  /// was created: the SnackBar Retry action uploads again without ever
  /// re-creating the comment.
  String? _retryImagePostId;
  Uint8List? _retryImageBytes;

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

  Future<void> _editPost(Post post) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null || profileId != post.authorProfileId) return;
    final bodyController = TextEditingController(text: post.body);
    // Save may also mark the attached image for removal (tapped × in the
    // dialog); removal runs only after the text edit succeeded, through
    // `agri_connect.remove_post_media` — never a Storage delete.
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) {
        String? pendingRemoval;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Consumer(
            builder: (dialogContext, ref, _) {
              final cs = Theme.of(dialogContext).colorScheme;
              final entriesAsync = ref.watch(postMediaEntriesProvider(post.id));
              final urlsAsync = ref.watch(postMediaUrlsProvider(post.id));
              final entries =
                  entriesAsync.value ?? const <Map<String, String>>[];
              final fileId = entries.isEmpty ? null : entries.first['id'];
              final urls = urlsAsync.value ?? const <String>[];
              final url = urls.isEmpty ? null : urls.first;

              Widget placeholder(bool spinning) => Container(
                width: 96,
                height: 96,
                color: cs.surfaceContainerHighest,
                child: spinning
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        Icons.broken_image_outlined,
                        size: 24,
                        color: cs.outline,
                      ),
              );

              return AlertDialog(
                title: const Text('Edit Post'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: bodyController,
                        decoration: const InputDecoration(labelText: 'Body'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      if (entriesAsync.isLoading && entriesAsync.value == null)
                        const SizedBox(
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (pendingRemoval != null)
                        Text(
                          'The image will be removed when you save.',
                          style: TextStyle(fontSize: 11.5, color: cs.outline),
                        )
                      else if (fileId != null)
                        Stack(
                          key: const ValueKey('comment_image_tile'),
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: url != null
                                  ? Image.network(
                                      url,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          placeholder(false),
                                    )
                                  : placeholder(true),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => pendingRemoval = fileId,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop({'saved': true, 'removeFileId': pendingRemoval}),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .editPost(
            discussionId: widget.discussionId,
            postId: post.id,
            body: bodyController.text.trim(),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save changes: $e')));
      return;
    }
    if (!mounted) return;
    ref.invalidate(
      postsProvider((discussionId: widget.discussionId, parentId: null)),
    );
    final removeFileId = result['removeFileId'] as String?;
    if (removeFileId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post updated.')));
      return;
    }
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .removePostImage(postId: post.id, fileId: removeFileId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post updated.')));
    } catch (e) {
      // The text is saved and the image stays — report only the removal.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Comment updated, but the image could not be removed: $e',
          ),
        ),
      );
    }
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
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () async {
              final discussion = discussionAsync.value;
              if (discussion == null) return;
              final profileId = ref.read(agriConnectProfileIdProvider);
              // Only show Edit for the discussion author. RLS remains
              // authoritative — this is a UI affordance, not authorization.
              if (profileId != null && profileId != discussion.createdBy) {
                return;
              }
              final result = await showDialog<Object>(
                context: context,
                builder: (_) => EditDiscussionDialog(discussion: discussion),
              );
              if (!context.mounted || result == null) return;
              final messenger = ScaffoldMessenger.of(context);
              if (result == editDiscussionSaved) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Discussion updated.')),
                );
              } else if (result is DiscussionEditException) {
                messenger.showSnackBar(
                  SnackBar(content: Text(result.userMessage)),
                );
              }
            },
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
                    // Always resolve media for this discussion (one bounded
                    // call) — also self-heals discussions whose metadata
                    // write failed at creation time.
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
          onEdit: () => _editPost(post),
          authorProfileId: ref.read(agriConnectProfileIdProvider),
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
                      onEdit: () => _editPost(reply),
                      authorProfileId: ref.read(agriConnectProfileIdProvider),
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
    final expectImages = discussion.mediaFileIds.isNotEmpty;
    final urlsAsync = ref.watch(discussionMediaUrlsProvider(discussion.id));
    final urls = (urlsAsync.value ?? const <String>[]).take(2).toList();
    if (urls.isEmpty) {
      if (urlsAsync.isLoading) {
        return const SizedBox(
          height: 72,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (!urlsAsync.hasError && !expectImages) {
        // No media exists for this discussion — render nothing.
        return const SizedBox.shrink();
      }
      // Surface the exact signing/authorization/response error (or a
      // promised-but-missing image) and let the user re-sign (tap retry).
      final message = urlsAsync.hasError
          ? 'Image unavailable: ${urlsAsync.error}\nTap to retry.'
          : 'Image unavailable. Tap to retry.';
      return GestureDetector(
        onTap: () => ref.invalidate(discussionMediaUrlsProvider(discussion.id)),
        child: Container(
          height: 72,
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: cs.outline),
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
              child: _imageTile(context, urls[i], height, discussion.id),
            ),
          ),
      ],
    );
  }

  Widget _imageTile(
    BuildContext context,
    String url,
    double height,
    String discussionId,
  ) {
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
          errorBuilder: (_, __, ___) => GestureDetector(
            // Failed load (e.g. expired signed URL or storage 403/404) —
            // re-run the provider so the URL is signed again.
            onTap: () =>
                ref.invalidate(discussionMediaUrlsProvider(discussionId)),
            child: Container(
              height: height,
              width: double.infinity,
              color: cs.surfaceContainerHighest,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 26,
                    color: cs.outline,
                  ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_composerImage != null)
            _imagePreview(
              _composerImage!,
              () => setState(() => _composerImage = null),
            ),
          Row(
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
              if (_composerImage == null)
                IconButton(
                  onPressed: _sending || _pickingImage
                      ? null
                      : () => _pickCommentImage(isReply: false),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                  ),
                  tooltip: 'Attach image',
                ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyImage != null)
          _imagePreview(_replyImage!, () => setState(() => _replyImage = null)),
        Row(
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
            if (_replyImage == null)
              IconButton(
                onPressed: _sending || _pickingImage
                    ? null
                    : () => _pickCommentImage(isReply: true),
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                tooltip: 'Attach image',
              ),
            IconButton(
              icon: Icon(Icons.send_rounded, size: 20, color: cs.primary),
              onPressed: _sending
                  ? null
                  : () => _submitPost(context, discussion, parentId),
              tooltip: 'Send',
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.outline),
              onPressed: () => setState(() => _replyingTo = null),
              tooltip: 'Cancel',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitPost(
    BuildContext context,
    Discussion discussion,
    String? parentId,
  ) async {
    if (_sending) return; // Extra taps must never double-post.
    final isReply = parentId != null;
    final controller = isReply ? _replyController : _composerController;
    final body = controller.text.trim();
    if (body.isEmpty) return;
    final image = isReply ? _replyImage : _composerImage;

    setState(() => _sending = true);
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .createPost(
            discussionId: discussion.id,
            parentPostId: parentId,
            body: body,
            image: image,
          );
      controller.clear();
      if (isReply) {
        setState(() {
          _replyingTo = null;
          _replyImage = null;
        });
      } else {
        setState(() => _composerImage = null);
      }
    } on PostAttachException catch (e) {
      // The comment was created; only the image upload failed. Clear the
      // draft (a retry must never re-create the comment) and keep the
      // bytes for an upload-only retry against the created post.
      controller.clear();
      if (isReply) {
        setState(() {
          _replyingTo = null;
          _replyImage = null;
        });
      } else {
        setState(() => _composerImage = null);
      }
      if (image != null) _armImageRetry(e.post.id, image, e.cause);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Pick one gallery image and prepare it with the shared listing
  /// pipeline (decode → bounded WebP ≤2 MiB). Failures keep the composer
  /// untouched and report once.
  Future<void> _pickCommentImage({required bool isReply}) async {
    if (_pickingImage) return;
    _pickingImage = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return; // Cancelled — nothing changes.
      final bytes = await picked.readAsBytes();
      final prepared = await const ListingImageProcessingService().prepare(
        bytes: bytes,
        sourceName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        if (isReply) {
          _replyImage = prepared.bytes;
        } else {
          _composerImage = prepared.bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add image: $e')));
    } finally {
      _pickingImage = false;
    }
  }

  /// Thumbnail for a picked-but-unsent image with a remove affordance —
  /// the send button stays the only path that uploads anything.
  Widget _imagePreview(Uint8List bytes, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 44,
                height: 44,
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Image ready to send',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove image',
          ),
        ],
      ),
    );
  }

  /// Keep the failed upload's bytes and show a SnackBar whose Retry action
  /// re-uploads against the already-created post — the comment is never
  /// created twice and is never deleted to compensate.
  void _armImageRetry(String postId, Uint8List bytes, Object cause) {
    _retryImagePostId = postId;
    _retryImageBytes = bytes;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Comment posted, but the image could not be uploaded: $cause',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Retry', onPressed: _retryImageUpload),
      ),
    );
  }

  /// Upload-only retry for an image whose comment already exists.
  Future<void> _retryImageUpload() async {
    final postId = _retryImagePostId;
    final bytes = _retryImageBytes;
    if (!mounted || postId == null || bytes == null) return;
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .attachPostImage(postId: postId, bytes: bytes);
      _retryImagePostId = null;
      _retryImageBytes = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    }
  }
}
