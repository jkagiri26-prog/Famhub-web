class ReputationRatingSummary {
  final String subjectId;
  final int verifiedRatingCount;
  final double verifiedRatingAverage;
  final Map<int, int> verifiedDistribution;
  final int unverifiedRatingCount;
  final Map<int, int> unverifiedDistribution;
  final int reviewCount;
  final DateTime? updatedAt;

  const ReputationRatingSummary({
    required this.subjectId,
    required this.verifiedRatingCount,
    required this.verifiedRatingAverage,
    required this.verifiedDistribution,
    required this.unverifiedRatingCount,
    required this.unverifiedDistribution,
    required this.reviewCount,
    this.updatedAt,
  });

  factory ReputationRatingSummary.fromJson(Map<String, dynamic> json) {
    Map<int, int> distribution(Object? value) {
      final source = value is Map ? value : const <String, dynamic>{};
      return {
        for (var star = 1; star <= 5; star++)
          star: (source['$star'] as num?)?.toInt() ?? 0,
      };
    }

    return ReputationRatingSummary(
      subjectId: json['subject_id']?.toString() ?? '',
      verifiedRatingCount:
          (json['verified_rating_count'] as num?)?.toInt() ?? 0,
      verifiedRatingAverage:
          (json['verified_rating_average'] as num?)?.toDouble() ?? 0,
      verifiedDistribution: distribution(json['verified_distribution']),
      unverifiedRatingCount:
          (json['unverified_rating_count'] as num?)?.toInt() ?? 0,
      unverifiedDistribution: distribution(json['unverified_distribution']),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
