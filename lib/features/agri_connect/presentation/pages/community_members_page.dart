/// ============================================================
/// AGRI CONNECT — COMMUNITY MEMBERS PAGE
/// ============================================================
///
/// Lists members. Admins/owners additionally see pending join requests and
/// moderation actions; any authenticated user can block a member. All
/// authorization is backend-enforced — the UI only exposes what the backend
/// role permits.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community_join_request.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/enums/community_enums.dart';
import '../../domain/enums/safety_enums.dart';
import '../../application/providers/community_provider.dart';
import '../../application/providers/agri_connect_providers.dart';
import '../../application/providers/moderation_provider.dart';
import '../format.dart';
import '../widgets/membership_badge.dart';

class CommunityMembersPage extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityMembersPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityMembersPage> createState() =>
      _CommunityMembersPageState();
}

class _CommunityMembersPageState extends ConsumerState<CommunityMembersPage> {
  late Future<List<CommunityJoinRequest>> _joinRequestsFuture;

  @override
  void initState() {
    super.initState();
    _joinRequestsFuture = _loadJoinRequests();
  }

  Future<List<CommunityJoinRequest>> _loadJoinRequests() {
    return ref
        .read(communityRepositoryProvider)
        .fetchJoinRequests(widget.communityId);
  }

  void _refreshJoinRequests() {
    setState(() => _joinRequestsFuture = _loadJoinRequests());
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(
      communityMembersProvider(widget.communityId),
    );
    final myMembershipAsync = ref.watch(
      myMembershipProvider(widget.communityId),
    );
    final canModerate = myMembershipAsync.value?.role.canModerate ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retryView(),
        data: (members) {
          final items = <Widget>[];
          if (canModerate) {
            items.add(_joinRequestsSection());
            if (members.isNotEmpty) items.add(const SizedBox(height: 20));
          }
          if (members.isEmpty) {
            items.add(
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No members yet.'),
                ),
              ),
            );
          } else {
            for (final member in members) {
              items.add(_memberTile(context, member, canModerate));
              items.add(const SizedBox(height: 8));
            }
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: items,
          );
        },
      ),
    );
  }

  Widget _retryView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load members.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(communityMembersProvider(widget.communityId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _joinRequestsSection() {
    return FutureBuilder<List<CommunityJoinRequest>>(
      future: _joinRequestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final requests = snapshot.data ?? const <CommunityJoinRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join requests',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            for (final request in requests)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile ${request.profileId.substring(0, 8)}…',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (request.message != null &&
                              request.message!.isNotEmpty)
                            Text(
                              request.message!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _reviewRequest(request, true),
                      child: const Text('Approve'),
                    ),
                    TextButton(
                      onPressed: () => _reviewRequest(request, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _reviewRequest(
    CommunityJoinRequest request,
    bool approve,
  ) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .reviewJoinRequest(requestId: request.id, approve: approve);
      _refreshJoinRequests();
      ref.invalidate(communityMembersProvider(widget.communityId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not review request: $e')));
    }
  }

  Widget _memberTile(
    BuildContext context,
    CommunityMember member,
    bool canModerate,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final myProfileId = ref.watch(agriConnectProfileIdProvider);
    final isSelf = myProfileId != null && member.profileId == myProfileId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Text(
              _initial(member.displayName),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName ?? 'Farmer',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          MembershipBadge(
            role: member.role,
            status: member.status,
            compact: true,
          ),
          if (!isSelf)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) => _handleAction(context, member, value),
              itemBuilder: (context) => [
                if (canModerate) ...const [
                  PopupMenuItem(value: 'warn', child: Text('Warn')),
                  PopupMenuItem(value: 'mute', child: Text('Mute')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                  PopupMenuItem(value: 'ban', child: Text('Ban')),
                  PopupMenuDivider(),
                ],
                const PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    CommunityMember member,
    String action,
  ) async {
    if (action == 'block') {
      await _block(member);
      return;
    }

    // Moderation actions — community-scoped, backend-authoritative.
    final types = {
      'warn': ModerationActionType.warn,
      'mute': ModerationActionType.mute,
      'remove': ModerationActionType.remove,
      'ban': ModerationActionType.ban,
    };
    try {
      await ref
          .read(moderationControllerProvider.notifier)
          .recordModerationAction(
            communityId: widget.communityId,
            targetType: 'profile',
            targetId: member.profileId,
            actionType: types[action]!,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_actionLabel(action)} applied.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moderation action failed: $e')));
    }
  }

  Future<void> _block(CommunityMember member) async {
    try {
      await ref
          .read(moderationControllerProvider.notifier)
          .blockUser(member.profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blocked ${member.displayName ?? 'user'}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not block user: $e')));
    }
  }

  String _actionLabel(String action) => switch (action) {
    'warn' => 'Warning',
    'mute' => 'Mute',
    'remove' => 'Removal',
    'ban' => 'Ban',
    _ => 'Action',
  };

  String _initial(String? name) {
    if (name == null || name.isEmpty) return 'F';
    return name[0].toUpperCase();
  }
}
