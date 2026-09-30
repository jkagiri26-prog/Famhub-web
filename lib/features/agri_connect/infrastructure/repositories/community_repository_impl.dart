/// ============================================================
/// AGRI CONNECT — COMMUNITY REPOSITORY IMPLEMENTATION
/// ============================================================
library;

import 'package:famhub_app/features/agri_connect/domain/entities/community.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/community_invitation.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/community_join_request.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/community_member.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/community_rule.dart';
import 'package:famhub_app/features/agri_connect/domain/enums/community_enums.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/community_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_profile_names.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/community_remote_data_source.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDataSource _dataSource;
  final AgriConnectProfileNames _profileNames;

  CommunityRepositoryImpl(this._dataSource, this._profileNames);

  @override
  Future<List<Community>> fetchDiscoverableCommunities({
    String? searchQuery,
    CommunityType? type,
  }) async {
    final rows = await _dataSource.fetchDiscoverableCommunities(
      searchQuery: searchQuery,
      type: type?.dbValue,
    );
    return rows.map(Community.fromJson).toList();
  }

  @override
  Future<List<Community>> fetchMyCommunities(String profileId) async {
    final ids = await _dataSource.fetchMembershipCommunityIds(profileId);
    final rows = await _dataSource.fetchCommunitiesByIds(ids);
    return rows.map(Community.fromJson).toList();
  }

  @override
  Future<Community?> fetchCommunityById(String communityId) async {
    final row = await _dataSource.fetchCommunityById(communityId);
    return row == null ? null : Community.fromJson(row);
  }

  @override
  Future<Community> createCommunity({
    required String name,
    required String slug,
    required CommunityType type,
    CommunityVisibility visibility = CommunityVisibility.public,
    String? description,
    String? entityId,
    String? locationId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final row = await _dataSource.createCommunity(
      name: name,
      slug: slug,
      type: type.dbValue,
      visibility: visibility.name,
      description: description,
      entityId: entityId,
      locationId: locationId,
      metadata: metadata,
    );
    if (row != null) return Community.fromJson(row);
    throw Exception('Community was created but could not be loaded.');
  }

  @override
  Future<List<CommunityMember>> fetchMembers(String communityId) async {
    final rows = await _dataSource.fetchMembers(communityId);
    final profileIds = rows
        .map((r) => r['profile_id']?.toString() ?? '')
        .toSet();
    final names = await _profileNames.resolve(profileIds);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final pid = map['profile_id']?.toString();
      if (pid != null && names.containsKey(pid)) {
        map['display_name'] = names[pid];
      }
      return CommunityMember.fromJson(map);
    }).toList();
  }

  @override
  Future<CommunityMember?> fetchMyMembership({
    required String communityId,
    required String profileId,
  }) async {
    final row = await _dataSource.fetchMembership(
      communityId: communityId,
      profileId: profileId,
    );
    return row == null ? null : CommunityMember.fromJson(row);
  }

  @override
  Future<void> joinCommunity({
    required String communityId,
    required String profileId,
  }) async {
    await _dataSource.joinCommunity(
      communityId: communityId,
      profileId: profileId,
    );
  }

  @override
  Future<void> leaveCommunity({
    required String communityId,
    required String profileId,
  }) async {
    await _dataSource.leaveCommunity(
      communityId: communityId,
      profileId: profileId,
    );
  }

  @override
  Future<bool> rejoinCommunity({
    required String communityId,
    required String profileId,
  }) async {
    final row = await _dataSource.rejoinCommunity(
      communityId: communityId,
      profileId: profileId,
    );
    return row != null;
  }

  @override
  Future<void> requestToJoin({
    required String communityId,
    required String profileId,
    String? message,
  }) async {
    await _dataSource.requestToJoin(
      communityId: communityId,
      profileId: profileId,
      message: message,
    );
  }

  @override
  Future<void> cancelJoinRequest({
    required String communityId,
    required String profileId,
  }) async {
    await _dataSource.cancelJoinRequest(
      communityId: communityId,
      profileId: profileId,
    );
  }

  @override
  Future<List<CommunityJoinRequest>> fetchJoinRequests(
    String communityId,
  ) async {
    final rows = await _dataSource.fetchJoinRequests(communityId);
    return rows.map(CommunityJoinRequest.fromJson).toList();
  }

  @override
  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _dataSource.reviewJoinRequest(
      requestId: requestId,
      status: approve ? 'approved' : 'rejected',
    );
  }

  @override
  Future<void> createInvitation({
    required String communityId,
    String? invitedProfileId,
    String? invitedEmail,
  }) async {
    if ((invitedProfileId == null || invitedProfileId.isEmpty) &&
        (invitedEmail == null || invitedEmail.isEmpty)) {
      throw ArgumentError('An invitation requires a profile or an email.');
    }
    await _dataSource.createInvitation(
      communityId: communityId,
      invitedProfileId: invitedProfileId,
      invitedEmail: invitedEmail,
    );
  }

  @override
  Future<List<CommunityInvitation>> fetchMyInvitations(String profileId) async {
    final rows = await _dataSource.fetchMyInvitations(profileId);
    return rows.map(CommunityInvitation.fromJson).toList();
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await _dataSource.setInvitationStatus(
      invitationId: invitationId,
      status: 'accepted',
    );
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _dataSource.setInvitationStatus(
      invitationId: invitationId,
      status: 'declined',
    );
  }

  @override
  Future<List<CommunityRule>> fetchRules(String communityId) async {
    final rows = await _dataSource.fetchRules(communityId);
    return rows.map(CommunityRule.fromJson).toList();
  }

  @override
  Future<void> createRule({
    required String communityId,
    required String title,
    String? description,
    required int order,
  }) async {
    await _dataSource.insertRule(
      communityId: communityId,
      title: title,
      description: description,
      order: order,
    );
  }

  @override
  Future<void> updateRule({
    required String ruleId,
    String? title,
    String? description,
    int? order,
  }) async {
    await _dataSource.updateRule(
      ruleId: ruleId,
      title: title,
      description: description,
      order: order,
    );
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await _dataSource.deleteRule(ruleId);
  }
}
