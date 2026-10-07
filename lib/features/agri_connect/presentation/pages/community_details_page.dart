/// ============================================================
/// AGRI CONNECT — COMMUNITY DETAILS PAGE (GROUP SHELL)
/// ============================================================
///
/// Tabbed community shell: Home | Discussions | Chat | Members.
/// Home is the group overview (about, announcements, discussions, rules,
/// membership). Backend/RLS remains authoritative for membership and
/// moderation — the UI only reflects backend state.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/enums/community_enums.dart';
import '../../domain/enums/messaging_enums.dart';
import '../../application/providers/community_provider.dart';
import '../../application/providers/discussion_provider.dart';
import '../../application/providers/announcement_provider.dart';
import '../../application/providers/agri_connect_providers.dart';
import '../../application/providers/messaging_provider.dart';
import '../format.dart';
import '../widgets/membership_badge.dart';
import '../widgets/announcement_card.dart';
import '../widgets/discussion_card.dart';
import '../widgets/conversation_view.dart';
import 'discussions_page.dart';
import 'community_members_page.dart';
import 'create_discussion_page.dart';
import 'discussion_details_page.dart';

class CommunityDetailsPage extends ConsumerWidget {
  final String communityId;

  const CommunityDetailsPage({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityAsync = ref.watch(communityDetailsProvider(communityId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(communityAsync.value?.name ?? 'Community'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Home'),
              Tab(text: 'Discussions'),
              Tab(text: 'Chat'),
              Tab(text: 'Members'),
            ],
          ),
        ),
        body: communityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorView(ref),
          data: (community) {
            if (community == null) {
              return const Center(child: Text('Community not found.'));
            }
            return TabBarView(
              children: [
                _HomeTab(community: community),
                DiscussionsPage(communityId: community.id, embedded: true),
                _CommunityChatTab(community: community),
                CommunityMembersPage(communityId: community.id, embedded: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorView(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load community.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(communityDetailsProvider(communityId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// HOME TAB — community overview
/// ─────────────────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  final Community community;

  const _HomeTab({required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(context, community),
        const SizedBox(height: 12),
        _MembershipActionCard(community: community),
        const SizedBox(height: 16),
        _primaryActions(context),
        const SizedBox(height: 20),
        _sectionTitle(Icons.campaign_outlined, cs.tertiary, 'Announcements'),
        const SizedBox(height: 8),
        _announcements(context, ref),
        const SizedBox(height: 20),
        _sectionTitle(Icons.forum_outlined, cs.primary, 'Recent discussions'),
        const SizedBox(height: 8),
        _discussions(context, ref),
        const SizedBox(height: 20),
        _sectionTitle(
          Icons.gavel_outlined,
          Colors.blue.shade600,
          'Community rules',
        ),
        const SizedBox(height: 8),
        _rules(context, ref),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _headerCard(BuildContext context, Community community) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.groups, color: cs.onPrimary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    if (community.isVerified) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 15,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified community',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            community.description?.isNotEmpty == true
                ? community.description!
                : 'This community has no description yet.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: community.description?.isNotEmpty == true
                  ? cs.onSurfaceVariant
                  : cs.outline,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                context,
                community.type.label,
                color: cs.primary,
                icon: Icons.category_outlined,
              ),
              _chip(
                context,
                community.visibility.label,
                color: cs.tertiary,
                icon: Icons.visibility_outlined,
              ),
              _chip(
                context,
                '${community.memberCount} '
                '${community.memberCount == 1 ? 'member' : 'members'}',
                color: cs.primary,
                icon: Icons.people_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = DefaultTabController.of(context);

    return Row(
      children: [
        Expanded(
          child: _actionButton(
            context,
            cs.primary,
            Icons.add_comment_outlined,
            'Start a discussion',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateDiscussionPage(communityId: community.id),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            context,
            cs.tertiary,
            Icons.chat_bubble_outline,
            'Community chat',
            () => tabs.animateTo(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            context,
            Colors.blue.shade600,
            Icons.people_outline,
            'Members',
            () => tabs.animateTo(3),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    Color color,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _announcements(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider(community.id));
    return async.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _inlineError('Could not load announcements.'),
      data: (list) {
        if (list.isEmpty) {
          return _emptyHint(context, 'No announcements yet.');
        }
        return Column(
          children: [
            for (final a in list.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnnouncementCard(announcement: a),
              ),
          ],
        );
      },
    );
  }

  Widget _discussions(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discussionsProvider(community.id));
    final authors =
        ref.watch(discussionAuthorNamesProvider(community.id)).value ??
        const <String, String>{};
    return async.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _inlineError('Could not load discussions.'),
      data: (list) {
        if (list.isEmpty) {
          return _emptyHint(
            context,
            'No discussions yet',
            actionLabel: 'Start a discussion',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateDiscussionPage(communityId: community.id),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final d in list.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DiscussionCard(
                  discussion: d,
                  authorName: authors[d.createdBy],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiscussionDetailsPage(discussionId: d.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _rules(BuildContext context, WidgetRef ref) {
    final async = ref.watch(communityRulesProvider(community.id));
    return async.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _inlineError('Could not load rules.'),
      data: (rules) {
        if (rules.isEmpty) {
          return _emptyHint(context, 'No community rules yet.');
        }
        return Column(
          children: [
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rule.order}. ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    String text, {
    IconData? icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(
    BuildContext context,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: cs.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    return Text(
      message,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MEMBERSHIP ACTION CARD
/// ─────────────────────────────────────────────────────────────
class _MembershipActionCard extends ConsumerStatefulWidget {
  final Community community;

  const _MembershipActionCard({required this.community});

  @override
  ConsumerState<_MembershipActionCard> createState() =>
      _MembershipActionCardState();
}

class _MembershipActionCardState extends ConsumerState<_MembershipActionCard>
    with AutomaticKeepAliveClientMixin {
  bool _busy = false;
  bool _requested = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final membershipAsync = ref.watch(
      myMembershipProvider(widget.community.id),
    );
    final membership = membershipAsync.value;

    if (membershipAsync.isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;

    if (membership == null) {
      if (_requested) {
        return _banner(
          Icons.hourglass_top,
          'Join request sent',
          'Your request to join is pending review.',
        );
      }
      final restricted = widget.community.requiresMembership;
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _join(context, restricted),
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  restricted ? Icons.pending_outlined : Icons.group_add,
                  size: 20,
                ),
          label: Text(restricted ? 'Request to Join' : 'Join Community'),
        ),
      );
    }

    if (!membership.isActive) {
      return Row(
        children: [
          MembershipBadge(role: membership.role, status: membership.status),
          const Spacer(),
          if (membership.status == MemberStatus.left)
            TextButton.icon(
              onPressed: _busy ? null : () => _rejoin(context),
              style: TextButton.styleFrom(
                foregroundColor: primary,
                backgroundColor: primary.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Join again'),
            ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are a member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
          MembershipBadge(
            role: membership.role,
            status: membership.status,
            compact: true,
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _leave(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade200),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context, bool restricted) async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(communityControllerProvider.notifier);
      if (restricted) {
        await controller.requestToJoin(widget.community.id);
        setState(() => _requested = true);
      } else {
        await controller.joinCommunity(widget.community.id);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not join community: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(BuildContext context) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(communityControllerProvider.notifier)
          .leaveCommunity(widget.community.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave community: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejoin(BuildContext context) async {
    setState(() => _busy = true);
    try {
      // Backend RPC decides the outcome: active owner for the creator,
      // pending approval for other returning members. The membership badge
      // refreshes from the provider.
      await ref
          .read(communityControllerProvider.notifier)
          .rejoinCommunity(widget.community.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not rejoin community: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _banner(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// CHAT TAB — community conversation
/// ─────────────────────────────────────────────────────────────
class _CommunityChatTab extends ConsumerStatefulWidget {
  final Community community;

  const _CommunityChatTab({required this.community});

  @override
  ConsumerState<_CommunityChatTab> createState() => _CommunityChatTabState();
}

class _CommunityChatTabState extends ConsumerState<_CommunityChatTab>
    with AutomaticKeepAliveClientMixin {
  bool _starting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final membership = ref
        .watch(myMembershipProvider(widget.community.id))
        .value;

    // Community chat requires an active membership — enforced by the backend.
    if (membership == null || !membership.isActive) {
      return _chatEmpty(
        'Join this community to chat with members.',
        icon: Icons.lock_outline,
        showStart: false,
      );
    }

    final conversationsAsync = ref.watch(conversationsProvider);
    final conversations = conversationsAsync.value ?? const [];

    Conversation? communityConversation;
    for (final c in conversations) {
      if (c.type == ConversationType.community &&
          c.communityId == widget.community.id) {
        communityConversation = c;
        break;
      }
    }

    if (conversationsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (communityConversation == null) {
      return _chatEmpty(
        'Quick conversations with members of this community.',
        icon: Icons.forum_outlined,
        showStart: true,
      );
    }

    return ConversationView(conversationId: communityConversation.id);
  }

  Future<void> _startChat() async {
    setState(() => _starting = true);
    try {
      await ref
          .read(messagingControllerProvider.notifier)
          .createConversation(
            type: ConversationType.community,
            title: widget.community.name,
            communityId: widget.community.id,
          );
      // conversationsProvider is invalidated by the controller; the tab will
      // rebuild and render the new conversation.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Widget _chatEmpty(
    String subtitle, {
    required IconData icon,
    required bool showStart,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(
                context,
              ).colorScheme.tertiary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            const Text(
              'Community Chat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (showStart) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _starting ? null : _startChat,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Start community chat'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
