class ReputationReview {
  final String id;
  final String subjectId;
  final int? rating;
  final String? title;
  final String body;
  final String verificationStatus;
  final String? reviewerDisplayName;
  final String? reviewerAvatar;
  final String? responseBody;
  final String? responseStatus;
  final DateTime? createdAt;

  const ReputationReview({
    required this.id,
    required this.subjectId,
    required this.rating,
    required this.title,
    required this.body,
    required this.verificationStatus,
    required this.reviewerDisplayName,
    required this.reviewerAvatar,
    required this.responseBody,
    required this.responseStatus,
    required this.createdAt,
  });

  factory ReputationReview.fromJson(Map<String, dynamic> json) {
    return ReputationReview(
      id: json['review_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt(),
      title: json['title']?.toString(),
      body: json['body']?.toString() ?? '',
      verificationStatus: json['verification_status']?.toString() ?? 'unverified',
      reviewerDisplayName: json['reviewer_display_name']?.toString(),
      reviewerAvatar: json['reviewer_avatar']?.toString(),
      responseBody: json['response_body']?.toString(),
      responseStatus: json['response_status']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  bool get isVerified => verificationStatus == 'verified';
}
