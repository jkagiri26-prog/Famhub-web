/// ============================================================
/// AGRI CONNECT — COMMUNITY RULE ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`community_rules`)
/// ============================================================
library;

class CommunityRule {
  final String id;
  final String communityId;
  final int order;
  final String title;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const CommunityRule({
    required this.id,
    required this.communityId,
    required this.order,
    required this.title,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory CommunityRule.fromJson(Map<String, dynamic> json) {
    return CommunityRule(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString() ?? '',
      order: (json['rule_order'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
