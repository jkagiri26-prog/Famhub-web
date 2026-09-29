/// ============================================================
/// AGRI CONNECT — POST ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`posts`)
///
/// A top-level post has `parentPostId == null`; a reply has a parent.
/// Only non-deleted replies contribute to `discussions.reply_count`.
/// ============================================================
library;

class Post {
  final String id;
  final String discussionId;
  final String authorProfileId;
  final String? parentPostId;
  final String body;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Resolved at query time (author display name).
  final String? authorName;

  /// Emoji → count, resolved at query time (may be omitted).
  final Map<String, int> reactionCounts;

  /// The current user's reaction (null when they have not reacted).
  final String? myReaction;

  const Post({
    required this.id,
    required this.discussionId,
    required this.authorProfileId,
    this.parentPostId,
    required this.body,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.reactionCounts = const {},
    this.myReaction,
  });

  bool get isReply => parentPostId != null;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id']?.toString() ?? '',
      discussionId: json['discussion_id']?.toString() ?? '',
      authorProfileId: json['author_profile_id']?.toString() ?? '',
      parentPostId: json['parent_post_id']?.toString(),
      body: json['body']?.toString() ?? '',
      isEdited: json['is_edited'] == true,
      editedAt: _parse(json['edited_at']),
      isDeleted: json['is_deleted'] == true,
      deletedAt: _parse(json['deleted_at']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parse(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      authorName: json['author_name']?.toString(),
      reactionCounts: _reactionCounts(json['reaction_counts']),
      myReaction: json['my_reaction']?.toString(),
    );
  }

  static Map<String, int> _reactionCounts(dynamic v) {
    if (v is Map) {
      return v.map(
        (k, val) => MapEntry(k.toString(), (val is num) ? val.toInt() : 0),
      );
    }
    return const {};
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
