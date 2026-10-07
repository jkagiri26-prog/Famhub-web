/// ============================================================
/// AGRI CONNECT — HOME TAB
/// ============================================================
///
/// Public discussion-centred landing page. The discussion feed is the
/// dominant content; supporting sections stay compact.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/community_provider.dart';
import '../../application/providers/discussion_provider.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/discussion.dart';
import '../widgets/agri_feed_card_placeholder_widget.dart';
import '../widgets/discussion_card.dart';
import 'community_details_page.dart';
import 'create_discussion_page.dart';
import 'discussion_details_page.dart';

class HomeTab extends ConsumerWidget {
  /// Switches the module shell to another top-level tab.
  final ValueChanged<int> onNavigate;

  const HomeTab({super.key, required this.onNavigate});

  static const int _feedLimit = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discussionsAsync = ref.watch(discussionsProvider(null));
    final authors =
        ref.watch(discussionAuthorNamesProvider(null)).value ??
        const <String, String>{};
    final communityNames = ref.watch(communityNamesProvider);
    final myCommunities =
        ref.watch(myCommunitiesProvider).value ?? const <Community>[];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _hero(context),
        const SizedBox(height: 18),
        _sectionHeader(
          'Public discussions',
          actionLabel: 'See all',
          onAction: () => onNavigate(2),
        ),
        const SizedBox(height: 6),
        ..._feed(context, ref, discussionsAsync, authors, communityNames),
        if (myCommunities.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionHeader(
            'My communities',
            actionLabel: 'See all',
            onAction: () => onNavigate(1),
          ),
          const SizedBox(height: 8),
          _communityStrip(context, myCommunities),
        ],
      ],
    );
  }

  // ── Hero ───────────────────────────────────────────────────

  Widget _hero(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ask a farming question',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Get answers from farmers across the network.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: () => _startDiscussion(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_comment_outlined, size: 20),
              label: const Text(
                'Start a discussion',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Feed ───────────────────────────────────────────────────

  List<Widget> _feed(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Discussion>> async,
    Map<String, String> authors,
    Map<String, String> communityNames,
  ) {
    return async.when(
      loading: () => [
        for (var i = 0; i < 3; i++)
          const AgriFeedCardPlaceholderWidget(
            title: 'Discussion',
            subtitle: '',
          ),
      ],
      error: (e, _) => [_errorBox(context, ref)],
      data: (discussions) {
        if (discussions.isEmpty) return [_emptyFeed(context)];

        final shown = discussions.length > _feedLimit
            ? discussions.sublist(0, _feedLimit)
            : discussions;

        return [
          for (final d in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DiscussionCard(
                discussion: d,
                authorName: authors[d.createdBy],
                communityName: d.communityId == null
                    ? null
                    : communityNames[d.communityId],
                onTap: () => _openDiscussion(context, d.id),
              ),
            ),
          if (discussions.length > _feedLimit)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onNavigate(2),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('See all discussions'),
              ),
            ),
        ];
      },
    );
  }

  Widget _emptyFeed(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 42, color: cs.tertiary),
          const SizedBox(height: 12),
          const Text(
            'No discussions yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to start an agricultural conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _startDiscussion(context),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start a discussion'),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const Text('Could not load discussions.'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => ref.invalidate(discussionsProvider(null)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────

  Widget _sectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  // ── My communities strip ───────────────────────────────────

  Widget _communityStrip(BuildContext context, List<Community> communities) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: communities.length > 8 ? 8 : communities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final c = communities[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CommunityDetailsPage(communityId: c.id),
              ),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      c.name.isEmpty ? 'C' : c.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.memberCount} '
                          '${c.memberCount == 1 ? 'member' : 'members'}',
                          style: TextStyle(fontSize: 11, color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────

  void _startDiscussion(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateDiscussionPage()));
  }

  void _openDiscussion(BuildContext context, String discussionId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionDetailsPage(discussionId: discussionId),
      ),
    );
  }
}
