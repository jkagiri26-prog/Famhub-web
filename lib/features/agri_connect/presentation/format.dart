/// ============================================================
/// AGRI CONNECT — PRESENTATION FORMAT HELPERS
/// ============================================================
///
/// Display labels + time formatting. Kept in the presentation layer so the
/// domain enums stay pure. Backend state remains authoritative.
/// ============================================================
library;

import '../domain/enums/announcement_enums.dart';
import '../domain/enums/community_enums.dart';
import '../domain/enums/discussion_enums.dart';
import '../domain/enums/messaging_enums.dart';

String agriTimeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} $hh:$mm';
}

String agriFullDate(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

extension CommunityTypeLabel on CommunityType {
  String get label => switch (this) {
    CommunityType.interest => 'Interest',
    CommunityType.location => 'Location',
    CommunityType.buyer => 'Buyer',
    CommunityType.selfHelp => 'Self Help',
    CommunityType.cooperative => 'Cooperative',
    CommunityType.organization => 'Organization',
    CommunityType.private => 'Private',
    CommunityType.project => 'Project',
  };
}

extension CommunityVisibilityLabel on CommunityVisibility {
  String get label => switch (this) {
    CommunityVisibility.public => 'Public',
    CommunityVisibility.private => 'Private',
    CommunityVisibility.restricted => 'Restricted',
  };
}

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
    MemberRole.member => 'Member',
    MemberRole.moderator => 'Moderator',
    MemberRole.admin => 'Admin',
    MemberRole.owner => 'Owner',
  };
}

extension MemberStatusLabel on MemberStatus {
  String get label => switch (this) {
    MemberStatus.pending => 'Pending',
    MemberStatus.active => 'Active',
    MemberStatus.suspended => 'Suspended',
    MemberStatus.banned => 'Banned',
    MemberStatus.left => 'Left',
    MemberStatus.rejected => 'Rejected',
  };
}

extension JoinRequestStatusLabel on JoinRequestStatus {
  String get label => switch (this) {
    JoinRequestStatus.pending => 'Pending',
    JoinRequestStatus.approved => 'Approved',
    JoinRequestStatus.rejected => 'Rejected',
    JoinRequestStatus.cancelled => 'Cancelled',
  };
}

extension DiscussionTypeLabel on DiscussionType {
  String get label => switch (this) {
    DiscussionType.question => 'Question',
    DiscussionType.discussion => 'Discussion',
    DiscussionType.announcement => 'Announcement',
    DiscussionType.poll => 'Poll',
  };
}

extension ConversationTypeLabel on ConversationType {
  String get label => switch (this) {
    ConversationType.direct => 'Direct',
    ConversationType.group => 'Group',
    ConversationType.community => 'Community',
    ConversationType.marketplace => 'Marketplace',
    ConversationType.support => 'Support',
    ConversationType.organization => 'Organization',
  };
}

extension MessageTypeLabel on MessageType {
  String get label => switch (this) {
    MessageType.text => 'Text',
    MessageType.image => 'Image',
    MessageType.video => 'Video',
    MessageType.document => 'Document',
    MessageType.audio => 'Audio',
    MessageType.system => 'System',
  };
}

extension AnnouncementTypeLabel on AnnouncementType {
  String get label => switch (this) {
    AnnouncementType.community => 'Community',
    AnnouncementType.organization => 'Organization',
    AnnouncementType.famhub => 'FAMHUB',
  };
}
