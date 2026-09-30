/// ============================================================
/// AGRI CONNECT — COMMUNITY REPOSITORY CONTRACT
/// ============================================================
///
/// Community + membership + join requests + invitations + rules.
/// Backend/RLS remains authoritative — the client never claims ownership.
/// ============================================================
library;

import '../entities/community.dart';
import '../entities/community_invitation.dart';
import '../entities/community_join_request.dart';
import '../entities/community_member.dart';
import '../entities/community_rule.dart';
import '../enums/community_enums.dart';

abstract class CommunityRepository {
  /// Discover eligible communities (RLS-scoped: public + membership).
  Future<List<Community>> fetchDiscoverableCommunities({
    String? searchQuery,
    CommunityType? type,
  });

  /// Communities the caller is an active member of.
  Future<List<Community>> fetchMyCommunities(String profileId);

  Future<Community?> fetchCommunityById(String communityId);

  /// Create a community via `agri_connect.create_community`.
  ///
  /// The creator + owner membership are bootstrapped by the backend.
  Future<Community> createCommunity({
    required String name,
    required String slug,
    required CommunityType type,
    CommunityVisibility visibility = CommunityVisibility.public,
    String? description,
    String? entityId,
    String? locationId,
    Map<String, dynamic> metadata = const {},
  });

  // ── Membership ──────────────────────────────────────────────
  Future<List<CommunityMember>> fetchMembers(String communityId);

  /// The caller's own membership row (or null when not a member).
  Future<CommunityMember?> fetchMyMembership({
    required String communityId,
    required String profileId,
  });

  /// Join an open community (direct active membership). RLS-scoped.
  Future<void> joinCommunity({
    required String communityId,
    required String profileId,
  });

  /// Leave a community (marks the caller's membership `left`). RLS-scoped.
  Future<void> leaveCommunity({
    required String communityId,
    required String profileId,
  });

  /// Rejoin a community the caller previously left.
  ///
  /// Updates the existing membership row (`left` → `pending`) by profile id.
  /// Never inserts or upserts — the backend policy only permits this UPDATE.
  /// Returns true when a `left` row was updated, false when none matched.
  Future<bool> rejoinCommunity({
    required String communityId,
    required String profileId,
  });

  // ── Join requests ──────────────────────────────────────────
  Future<void> requestToJoin({
    required String communityId,
    required String profileId,
    String? message,
  });

  Future<void> cancelJoinRequest({
    required String communityId,
    required String profileId,
  });

  Future<List<CommunityJoinRequest>> fetchJoinRequests(String communityId);

  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  });

  // ── Invitations ────────────────────────────────────────────
  Future<void> createInvitation({
    required String communityId,
    String? invitedProfileId,
    String? invitedEmail,
  });

  Future<List<CommunityInvitation>> fetchMyInvitations(String profileId);

  Future<void> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId);

  // ── Rules ──────────────────────────────────────────────────
  Future<List<CommunityRule>> fetchRules(String communityId);

  Future<void> createRule({
    required String communityId,
    required String title,
    String? description,
    required int order,
  });

  Future<void> updateRule({
    required String ruleId,
    String? title,
    String? description,
    int? order,
  });

  Future<void> deleteRule(String ruleId);
}
