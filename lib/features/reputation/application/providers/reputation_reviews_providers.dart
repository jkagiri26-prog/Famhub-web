import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/reputation_reviews_service.dart';

final reputationReviewsServiceProvider = Provider<ReputationReviewsService>((
  ref,
) {
  return ReputationReviewsService();
});
