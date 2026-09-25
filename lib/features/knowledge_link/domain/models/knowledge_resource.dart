/// ============================================================
/// KNOWLEDGE RESOURCE MODELS (RESOLVER RESULT + DETAIL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/domain/models/
///
/// Read models mirroring the `public.resolve_knowledge_resources` contract
/// and the `knowledge` schema (resources → resource_versions → sections →
/// content_blocks). The Flutter side NEVER re-implements the matching
/// algorithm — it only renders what the backend resolver returns.
/// ============================================================
library;

/// A single resource returned by `public.resolve_knowledge_resources`.
class KnowledgeResourceMatch {
  /// `knowledge.resources.id`.
  final String resourceId;

  /// `knowledge.resource_types.code` (e.g. 'quick_guide', 'general_guide').
  final String? resourceTypeCode;

  /// `knowledge.resource_types.name` (e.g. 'Quick Guide').
  final String? resourceTypeName;

  final String title;
  final String? slug;

  /// `knowledge.resource_versions.id` of the published version.
  final String? publishedVersionId;

  /// `knowledge.resource_versions.version_number` of the published version.
  final int? versionNumber;

  /// Which canonical dimensions matched (e.g. item, variant, location).
  final List<String> matchedDimensions;

  /// Resolver relevance score.
  final double? specificityScore;

  /// Human-readable explanation of why this resource matched.
  final String? matchReason;

  const KnowledgeResourceMatch({
    required this.resourceId,
    this.resourceTypeCode,
    this.resourceTypeName,
    required this.title,
    this.slug,
    this.publishedVersionId,
    this.versionNumber,
    this.matchedDimensions = const [],
    this.specificityScore,
    this.matchReason,
  });

  /// Defensive mapping over the resolver's snake_case row.
  factory KnowledgeResourceMatch.fromMap(Map<String, dynamic> map) {
    return KnowledgeResourceMatch(
      resourceId: _str(map['resource_id'] ?? map['id'] ?? map['resourceId']),
      resourceTypeCode: _str(
          map['resource_type_code'] ?? map['resource_type'] ?? map['resourceTypeCode']),
      resourceTypeName:
          _str(map['resource_type_name'] ?? map['resourceTypeName']),
      title: _str(map['title']),
      slug: _str(map['slug']),
      publishedVersionId: _str(
          map['published_version_id'] ?? map['published_version'] ?? map['publishedVersionId']),
      versionNumber: _int(map['version_number'] ?? map['versionNumber']),
      matchedDimensions:
          _strList(map['matched_dimensions'] ?? map['matchedDimensions']),
      specificityScore: _double(
          map['specificity_score'] ?? map['specificityScore']),
      matchReason: _str(map['match_reason'] ?? map['matchReason']),
    );
  }

  /// A compact subtitle combining match reason and resource type, e.g.
  /// "Harvest & Post-Harvest · Quick Guide".
  String get subtitle {
    final parts = <String>[
      if (matchReason != null && matchReason!.trim().isNotEmpty)
        matchReason!.trim(),
      if (resourceTypeName != null && resourceTypeName!.trim().isNotEmpty)
        resourceTypeName!.trim(),
    ];
    return parts.join(' · ');
  }

  static String _str(Object? value) {
    if (value == null) return '';
    return value.toString();
  }

  static int? _int(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _double(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<String> _strList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final raw = value.toString();
    if (raw.isEmpty) return const [];
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}

/// A section within a published resource version, in stored order.
class KnowledgeSection {
  final String id;
  final String title;
  final int sectionOrder;
  final String? summary;
  final List<KnowledgeContentBlock> blocks;

  const KnowledgeSection({
    required this.id,
    required this.title,
    required this.sectionOrder,
    this.summary,
    this.blocks = const [],
  });
}

/// A content block within a section, in stored order.
class KnowledgeContentBlock {
  final String id;
  final String blockType;
  final int blockOrder;
  final Map<String, dynamic> content;

  const KnowledgeContentBlock({
    required this.id,
    required this.blockType,
    required this.blockOrder,
    this.content = const {},
  });

  /// Best-effort plain text for a block (used by compact rendering).
  String? get text {
    if (content.isEmpty) return null;
    final direct = content['text'] ?? content['body'] ?? content['value'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    return null;
  }
}

/// The published resource/version loaded for the guide detail screen.
class KnowledgeResourceDetail {
  final String resourceId;

  /// `knowledge.resource_versions.id` of the published version.
  final String versionId;
  final int versionNumber;
  final String title;
  final String? summary;
  final String? resourceTypeCode;
  final String? resourceTypeName;
  final List<KnowledgeSection> sections;

  const KnowledgeResourceDetail({
    required this.resourceId,
    required this.versionId,
    required this.versionNumber,
    required this.title,
    this.summary,
    this.resourceTypeCode,
    this.resourceTypeName,
    this.sections = const [],
  });
}

/// ============================================================
/// CONTEXTUAL KNOWLEDGE DATA (RESOLVER RESULT ENVELOPE)
/// ============================================================
///
/// Groups the resources returned by Knowledge Link with the future
/// Agri Connect discussion surface, so both can eventually serve the SAME
/// canonical context without Knowledge Link absorbing community content.
///
///   Canonical Context
///         │
///         ├── Knowledge Link  → guides / curated knowledge  (now)
///         │
///         └── Agri Connect    → discussions / farmer experience (future)
///
/// `discussions` is intentionally an opaque placeholder — Agri Connect is
/// NOT built yet. Do not populate it with fake content; Knowledge Link must
/// not absorb community-generated content.
/// ============================================================
class ContextualKnowledgeData {
  final List<KnowledgeResourceMatch> guides;

  /// Future Agri Connect surface (typed entries will be supplied by
  /// Agri Connect later). Always empty today.
  final List<Object> discussions;

  const ContextualKnowledgeData({
    this.guides = const [],
    this.discussions = const [],
  });
}
