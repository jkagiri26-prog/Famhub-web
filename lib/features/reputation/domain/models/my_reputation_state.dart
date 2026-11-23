class MyReputationState {
  final String? ratingId;
  final int? rating;
  final String? ratingVerificationStatus;
  final String? reviewId;
  final String? reviewTitle;
  final String? reviewBody;
  final String? reviewRatingId;
  final String? reviewVerificationStatus;
  final String? reviewPublicIdentityMode;

  const MyReputationState({
    this.ratingId,
    this.rating,
    this.ratingVerificationStatus,
    this.reviewId,
    this.reviewTitle,
    this.reviewBody,
    this.reviewRatingId,
    this.reviewVerificationStatus,
    this.reviewPublicIdentityMode,
  });

  factory MyReputationState.fromJson(Map<String, dynamic> json) {
    return MyReputationState(
      ratingId: json['rating_id']?.toString(),
      rating: (json['rating'] as num?)?.toInt(),
      ratingVerificationStatus:
          json['rating_verification_status']?.toString(),
      reviewId: json['review_id']?.toString(),
      reviewTitle: json['review_title']?.toString(),
      reviewBody: json['review_body']?.toString(),
      reviewRatingId: json['review_rating_id']?.toString(),
      reviewVerificationStatus:
          json['review_verification_status']?.toString(),
      reviewPublicIdentityMode:
          json['review_public_identity_mode']?.toString(),
    );
  }
}
