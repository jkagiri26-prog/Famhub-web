/// ============================================================
/// AGRI CONNECT — COMMUNITY PROVIDERS
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/entities/community_invitation.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/entities/community_rule.dart';
import '../../domain/enums/community_enums.dart';
import '../../domain/repositories/community_repository.dart';
import 'agri_connect_providers.dart';

/// Discoverable communities (public + my memberships), with search + type.
final discoverCommunitiesProvider =
    FutureProvider.family<List<Community>, ({String? query, String? type})>((
      ref,
      filters,
    ) async {
      final repo = ref.watch(communityRepositoryProvider);
      final raw = filters.type;
      CommunityType? type;
      if (raw != null && raw.isNotEmpty) {
        for (final t in CommunityType.values) {
          if (t.name == raw || t.dbValue == raw) {
            type = t;
            break;
          }
        }
      }
      return repo.fetchDiscoverableCommunities(
        searchQuery: filters.query,
        type: type,
      );
    });

/// Communities the caller is an active member of.
final myCommunitiesProvider = FutureProvider<List<Community>>((ref) async {
  final profileId = ref.watch(agriConnectProfileIdProvider);
  if (profileId == null) return const [];
  return ref.watch(communityRepositoryProvider).fetchMyCommunities(profileId);
});

final communityDetailsProvider = FutureProvider.family<Community?, String>((
  ref,
  communityId,
) async {
  return ref.watch(communityRepositoryProvider).fetchCommunityById(communityId);
});

final communityMembersProvider =
    FutureProvider.family<List<CommunityMember>, String>((
      ref,
      communityId,
    ) async {
      return ref.watch(communityRepositoryProvider).fetchMembers(communityId);
    });

final myMembershipProvider = FutureProvider.family<CommunityMember?, String>((
  ref,
  communityId,
) async {
  final profileId = ref.watch(agriConnectProfileIdProvider);
  if (profileId == null) return null;
  return ref
      .watch(communityRepositoryProvider)
      .fetchMyMembership(communityId: communityId, profileId: profileId);
});

final communityRulesProvider =
    FutureProvider.family<List<CommunityRule>, String>((
      ref,
      communityId,
    ) async {
      return ref.watch(communityRepositoryProvider).fetchRules(communityId);
    });

final myInvitationsProvider = FutureProvider<List<CommunityInvitation>>((
  ref,
) async {
  final profileId = ref.watch(agriConnectProfileIdProvider);
  if (profileId == null) return const [];
  return ref.watch(communityRepositoryProvider).fetchMyInvitations(profileId);
});

/// Mutation controller for community + membership operations.
class CommunityController extends Notifier<void> {
  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void build() {}

  Future<Community> createCommunity({
    required String name,
    required String slug,
    required CommunityType type,
    CommunityVisibility visibility = CommunityVisibility.public,
    String? description,
  }) async {
    final community = await _repo.createCommunity(
      name: name,
      slug: slug,
      type: type,
      visibility: visibility,
      description: description,
    );
    _invalidate();
    return community;
  }

  Future<void> joinCommunity(String communityId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to join a community.');
    }
    // A previously-left membership may exist but be hidden from SELECT
    // (the RLS read policy can omit non-active rows). Prefer updating that
    // row back to `pending` via UPDATE; only insert a fresh active membership
    // when no `left` row exists.
    final rejoined = await _repo.rejoinCommunity(
      communityId: communityId,
      profileId: profileId,
    );
    if (!rejoined) {
      await _repo.joinCommunity(communityId: communityId, profileId: profileId);
    }
    _invalidate(communityId);
  }

  Future<void> leaveCommunity(String communityId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) return;
    await _repo.leaveCommunity(communityId: communityId, profileId: profileId);
    _invalidate(communityId);
  }

  Future<bool> rejoinCommunity(String communityId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to rejoin a community.');
    }
    final rejoined = await _repo.rejoinCommunity(
      communityId: communityId,
      profileId: profileId,
    );
    _invalidate(communityId);
    return rejoined;
  }

  Future<void> requestToJoin(String communityId, {String? message}) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to request to join.');
    }
    await _repo.requestToJoin(
      communityId: communityId,
      profileId: profileId,
      message: message,
    );
    _invalidate(communityId);
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _repo.acceptInvitation(invitationId);
    ref.invalidate(myInvitationsProvider);
    ref.invalidate(myCommunitiesProvider);
  }

  Future<void> declineInvitation(String invitationId) async {
    await _repo.declineInvitation(invitationId);
    ref.invalidate(myInvitationsProvider);
  }

  void _invalidate([String? communityId]) {
    ref.invalidate(discoverCommunitiesProvider);
    ref.invalidate(myCommunitiesProvider);
    if (communityId != null) {
      ref.invalidate(communityDetailsProvider(communityId));
      ref.invalidate(communityMembersProvider(communityId));
      ref.invalidate(myMembershipProvider(communityId));
    }
  }
}

final communityControllerProvider = NotifierProvider<CommunityController, void>(
  CommunityController.new,
);
