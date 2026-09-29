/// ============================================================
/// AGRI CONNECT — COMMUNITY DETAILS PAGE
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/enums/community_enums.dart';
import '../../domain/enums/messaging_enums.dart';
import '../../application/providers/community_provider.dart';
import '../../application/providers/discussion_provider.dart';
import '../../application/providers/announcement_provider.dart';
import '../../application/providers/agri_connect_providers.dart';
import '../../application/providers/messaging_provider.dart';
import '../format.dart';
import '../widgets/community_card.dart';
import '../widgets/membership_badge.dart';
import '../widgets/announcement_card.dart';
import '../widgets/discussion_card.dart';
import 'community_members_page.dart';
import 'discussions_page.dart';
import 'discussion_details_page.dart';
import 'conversation_page.dart';

class CommunityDetailsPage extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailsPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailsPage> createState() =>
      _CommunityDetailsPageState();
}

class _CommunityDetailsPageState extends ConsumerState<CommunityDetailsPage> {
  bool _busy = false;
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final communityAsync = ref.watch(
      communityDetailsProvider(widget.communityId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(communityAsync.value?.name ?? 'Community'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: communityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          onRetry: () =>
              ref.invalidate(communityDetailsProvider(widget.communityId)),
        ),
        data: (community) {
          if (community == null) {
            return const Center(child: Text('Community not found.'));
          }
          return _content(context, community);
        },
      ),
    );
  }

  Widget _content(BuildContext context, Community community) {
    final membershipAsync = ref.watch(myMembershipProvider(widget.communityId));
    final rulesAsync = ref.watch(communityRulesProvider(widget.communityId));
    final announcementsAsync = ref.watch(
      announcementsProvider(widget.communityId),
    );
    final discussionsAsync = ref.watch(discussionsProvider(widget.communityId));

    final membership = membershipAsync.value;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        CommunityCard(
          community: community,
          isMember: membership?.isActive ?? false,
        ),
        const SizedBox(height: 16),
        _membershipActions(context, community, membership),
        const SizedBox(height: 16),
        _quickActions(context, community, membership),
        const SizedBox(height: 20),
        _sectionTitle('Announcements'),
        const SizedBox(height: 8),
        _announcements(announcementsAsync),
        const SizedBox(height: 20),
        _sectionTitle('Rules'),
        const SizedBox(height: 8),
        _rules(rulesAsync, membership),
        const SizedBox(height: 20),
        _sectionTitle('Discussions'),
        const SizedBox(height: 8),
        _discussions(discussionsAsync, membership),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _membershipActions(
    BuildContext context,
    Community community,
    CommunityMember? membership,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    if (membership == null) {
      if (_requested) {
        return _banner(
          Icons.hourglass_top,
          'Join request sent',
          'Your request to join is pending review.',
        );
      }
      final restricted = community.requiresMembership;
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _join(context, community, restricted),
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
          if (membership.status == MemberStatus.left ||
              membership.status == MemberStatus.rejected)
            TextButton(
              onPressed: _busy ? null : () => _join(context, community, false),
              child: const Text('Join again'),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MembershipBadge(role: membership.role, status: membership.status),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _leave(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Leave'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActions(
    BuildContext context,
    Community community,
    CommunityMember? membership,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _quickTile(
          context,
          Icons.forum_outlined,
          'Discussions',
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DiscussionsPage(communityId: community.id),
            ),
          ),
        ),
        _quickTile(
          context,
          Icons.people_outline,
          'Members',
          () => _openMembers(context),
        ),
        _quickTile(
          context,
          Icons.chat_bubble_outline,
          'Community Chat',
          () => _openCommunityChat(context, community),
        ),
      ],
    );
  }

  Widget _quickTile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCommunityChat(
    BuildContext context,
    Community community,
  ) async {
    setState(() => _busy = true);
    try {
      final conversation = await ref
          .read(messagingControllerProvider.notifier)
          .createConversation(
            type: ConversationType.community,
            title: community.name,
            communityId: community.id,
          );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationPage(conversationId: conversation.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMembers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityMembersPage(communityId: widget.communityId),
      ),
    );
  }

  Future<void> _join(
    BuildContext context,
    Community community,
    bool restricted,
  ) async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(communityControllerProvider.notifier);
      if (restricted) {
        await controller.requestToJoin(community.id);
        setState(() => _requested = true);
      } else {
        await controller.joinCommunity(community.id);
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
          .leaveCommunity(widget.communityId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not leave community: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _announcements(announcementsAsync) {
    return announcementsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'No announcements.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          );
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

  Widget _rules(rulesAsync, CommunityMember? membership) {
    return rulesAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (rules) {
        if (rules.isEmpty) {
          return Text(
            'No rules yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          );
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

  Widget _discussions(discussionsAsync, CommunityMember? membership) {
    return discussionsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (discussions) {
        if (discussions.isEmpty) {
          return Text(
            'No discussions in this community.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          );
        }
        return Column(
          children: [
            for (final d in discussions.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DiscussionCard(
                  discussion: d,
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

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load community.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
