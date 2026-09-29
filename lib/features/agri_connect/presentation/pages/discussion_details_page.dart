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

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _header(context, discussion, canModerate),
              const SizedBox(height: 16),
              postsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load posts.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          discussion.isLocked
                              ? 'This discussion is locked.'
                              : 'No replies yet. Be the first to reply.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _post(context, discussion, post),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (!discussion.isLocked) _composer(context, discussion),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    Discussion discussion,
    bool canModerate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  discussion.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (discussion.isPinned)
                Icon(Icons.push_pin, size: 18, color: Colors.grey.shade500),
              if (discussion.isLocked)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _tag(discussion.type.label),
              _tag('${discussion.replyCount} replies'),
              _tag('${discussion.viewCount} views'),
              Text(
                '${discussion.type.label} · ${agriTimeAgo(discussion.createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
      ),
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

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _post(BuildContext context, Discussion discussion, Post post) {
    final repliesAsync = ref.watch(
      postsProvider((discussionId: discussion.id, parentId: post.id)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostTile(
          post: post,
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
            return Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Column(
                children: [
                  for (final reply in replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PostTile(
                        post: reply,
                        canReply: false,
                        onReport: () => showAgriReportSheet(
                          context,
                          ref,
                          targetType: ReportTargetType.post,
                          targetId: reply.id,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (_replyingTo == post.id)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 8),
            child: _replyComposer(context, discussion, post.id),
          ),
      ],
    );
  }

  Widget _composer(BuildContext context, Discussion discussion) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composerController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Add a reply…',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending
                ? null
                : () => _submitPost(context, discussion, null),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send, size: 20),
          onPressed: () => _submitPost(context, discussion, parentId),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() => _replyingTo = null),
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
