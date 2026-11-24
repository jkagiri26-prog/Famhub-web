import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/reputation_reviews_providers.dart';
import '../../domain/models/my_reputation_state.dart';
import '../../domain/models/reputation_rating_summary.dart';
import '../../domain/models/reputation_review.dart';

enum ReputationSubjectKind { product, seller }

class ReputationSubjectRatings extends ConsumerStatefulWidget {
  final ReputationSubjectKind kind;
  final String canonicalId;
  final String title;

  const ReputationSubjectRatings({
    super.key,
    required this.kind,
    required this.canonicalId,
    required this.title,
  });

  @override
  ConsumerState<ReputationSubjectRatings> createState() =>
      _ReputationSubjectRatingsState();
}

class _ReputationSubjectRatingsState
    extends ConsumerState<ReputationSubjectRatings> {
  late Future<_RatingsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String?> _resolveSubject() {
    final service = ref.read(reputationReviewsServiceProvider);
    return widget.kind == ReputationSubjectKind.product
        ? service.resolveProductSubject(widget.canonicalId)
        : service.resolveSellerSubject(widget.canonicalId);
  }

  Future<String> _ensureSubject() {
    final service = ref.read(reputationReviewsServiceProvider);
    return widget.kind == ReputationSubjectKind.product
        ? service.ensureProductSubject(widget.canonicalId)
        : service.ensureSellerSubject(widget.canonicalId);
  }

  Future<_RatingsData> _load() async {
    final service = ref.read(reputationReviewsServiceProvider);
    final subjectId = await _resolveSubject();
    if (subjectId == null) {
      return const _RatingsData(subjectId: null);
    }
    final summary = await service.fetchSummary(subjectId);
    final reviews = await service.fetchReviews(subjectId);
    final myState = await service.fetchMyState(subjectId);
    return _RatingsData(
      subjectId: subjectId,
      summary: summary,
      reviews: reviews,
      myState: myState,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _submitRating({int? existingRating}) async {
    final service = ref.read(reputationReviewsServiceProvider);
    final selected = await _showRatingSheet(existingRating ?? 5);
    if (selected == null) return;
    try {
      final subjectId = await _ensureSubject();
      final state = await service.fetchMyState(subjectId);
      if (state?.ratingId != null) {
        await service.editRating(ratingId: state!.ratingId!, rating: selected);
      } else {
        await service.submitRating(subjectId: subjectId, rating: selected);
      }
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save rating: $e')));
    }
  }

  Future<void> _submitReview({_RatingsData? data}) async {
    final service = ref.read(reputationReviewsServiceProvider);
    final current = data?.myState;
    final result = await _showReviewSheet(
      initialTitle: current?.reviewTitle,
      initialBody: current?.reviewBody,
      initialAnonymous: current?.reviewPublicIdentityMode == 'anonymous',
      canLinkRating: current?.ratingId != null,
      initialLinkRating: current?.reviewRatingId != null,
    );
    if (result == null) return;
    try {
      final subjectId = await _ensureSubject();
      final state = await service.fetchMyState(subjectId);
      if (state?.reviewId != null) {
        await service.editReview(
          reviewId: state!.reviewId!,
          body: result.body,
          title: result.title,
          ratingId: result.linkRating ? state.ratingId : null,
          publicIdentityMode: result.anonymous ? 'anonymous' : 'display_name',
        );
      } else {
        await service.submitReview(
          subjectId: subjectId,
          body: result.body,
          title: result.title,
          ratingId: result.linkRating ? state?.ratingId : null,
          publicIdentityMode: result.anonymous ? 'anonymous' : 'display_name',
        );
      }
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save review: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RatingsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snapshot.data ?? const _RatingsData(subjectId: null);
        return _RatingsBody(
          title: widget.title,
          data: data,
          signedIn: ref.read(reputationReviewsServiceProvider).isSignedIn,
          onRate: () => _submitRating(existingRating: data.myState?.rating),
          onReview: () => _submitReview(data: data),
        );
      },
    );
  }

  Future<int?> _showRatingSheet(int initial) async {
    var selected = initial;
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate ${widget.title.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Stars'),
                    items: [
                      for (var star = 1; star <= 5; star++)
                        DropdownMenuItem(
                          value: star,
                          child: Text('$star star${star == 1 ? '' : 's'}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setModalState(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Save rating'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<_ReviewInput?> _showReviewSheet({
    String? initialTitle,
    String? initialBody,
    bool initialAnonymous = false,
    bool canLinkRating = false,
    bool initialLinkRating = false,
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final bodyController = TextEditingController(text: initialBody);
    var anonymous = initialAnonymous;
    var linkRating = initialLinkRating;
    String? bodyError;
    final result = await showModalBottomSheet<_ReviewInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write a review for ${widget.title.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                      ),
                    ),
                    TextField(
                      controller: bodyController,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 20000,
                      onChanged: (_) {
                        if (bodyError != null) {
                          setModalState(() => bodyError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Review',
                        errorText: bodyError,
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: anonymous,
                      onChanged: (value) =>
                          setModalState(() => anonymous = value ?? false),
                      title: const Text('Publish anonymously'),
                    ),
                    if (canLinkRating)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: linkRating,
                        onChanged: (value) =>
                            setModalState(() => linkRating = value ?? false),
                        title: const Text('Attach my existing rating'),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final body = bodyController.text.trim();
                          if (body.isEmpty) return;
                          final privacyError = _publicReviewTextError(body);
                          if (privacyError != null) {
                            setModalState(() => bodyError = privacyError);
                            return;
                          }
                          Navigator.pop(
                            context,
                            _ReviewInput(
                              title: titleController.text.trim().isEmpty
                                  ? null
                                  : titleController.text.trim(),
                              body: body,
                              anonymous: anonymous,
                              linkRating: linkRating,
                            ),
                          );
                        },
                        child: const Text('Save review'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    titleController.dispose();
    bodyController.dispose();
    return result;
  }
}

class _RatingsBody extends StatelessWidget {
  final String title;
  final _RatingsData data;
  final bool signedIn;
  final VoidCallback onRate;
  final VoidCallback onReview;

  const _RatingsBody({
    required this.title,
    required this.data,
    required this.signedIn,
    required this.onRate,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (signedIn) ...[
              TextButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_outline, size: 18),
                label: Text(
                  data.myState?.ratingId == null ? 'Rate' : 'Edit rating',
                ),
              ),
              TextButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text(
                  data.myState?.reviewId == null ? 'Review' : 'Edit review',
                ),
              ),
            ],
          ],
        ),
        if (summary == null)
          Text(
            'No ratings yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else ...[
          Row(
            children: [
              Text(
                summary.verifiedRatingAverage.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _Stars(rating: summary.verifiedRatingAverage),
              const SizedBox(width: 8),
              Text(
                '${summary.verifiedRatingCount} verified',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(width: 12, child: Text('$star')),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: summary.verifiedRatingCount == 0
                          ? 0
                          : (summary.verifiedDistribution[star] ?? 0) /
                                summary.verifiedRatingCount,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${summary.verifiedDistribution[star] ?? 0}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'}'
            '${summary.unverifiedRatingCount > 0 ? ' · ${summary.unverifiedRatingCount} unverified rating${summary.unverifiedRatingCount == 1 ? '' : 's'}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          if (data.reviews.isEmpty)
            Text(
              'No written reviews yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            for (final review in data.reviews) _ReviewTile(review: review),
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReputationReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReviewerAvatar(review: review),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _publicReviewerName(review.reviewerDisplayName),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (review.rating != null)
                _Stars(rating: review.rating!.toDouble()),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: review.isVerified
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  review.isVerified ? 'Verified' : 'Unverified',
                  style: TextStyle(
                    fontSize: 10,
                    color: review.isVerified
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.title!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 4),
          Text(review.body),
          if (review.responseBody != null &&
              review.responseBody!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Seller response: ${review.responseBody!}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0, 5).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            clamped >= i + 1
                ? Icons.star
                : (clamped > i ? Icons.star_half : Icons.star_border),
            size: 15,
            color: Colors.amber.shade700,
          ),
      ],
    );
  }
}

class _RatingsData {
  final String? subjectId;
  final ReputationRatingSummary? summary;
  final List<ReputationReview> reviews;
  final MyReputationState? myState;

  const _RatingsData({
    required this.subjectId,
    this.summary,
    this.reviews = const [],
    this.myState,
  });
}

class _ReviewInput {
  final String? title;
  final String body;
  final bool anonymous;
  final bool linkRating;

  const _ReviewInput({
    this.title,
    required this.body,
    required this.anonymous,
    required this.linkRating,
  });
}

String _publicReviewerName(String? displayName) {
  final value = displayName?.trim() ?? '';
  if (value.isEmpty) return 'Anonymous';
  return value.split(RegExp(r'\s+')).first;
}

String? _publicReviewTextError(String text) {
  final email = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  if (email.hasMatch(text)) {
    return 'Remove email addresses from public reviews.';
  }
  final phone = RegExp(r'(?:\+?\d[\d\s().-]{7,}\d)');
  if (phone.hasMatch(text)) {
    return 'Remove phone numbers from public reviews.';
  }
  return null;
}

class _ReviewerAvatar extends StatelessWidget {
  final ReputationReview review;

  const _ReviewerAvatar({required this.review});

  @override
  Widget build(BuildContext context) {
    final avatar = review.reviewerAvatar?.trim();
    final hasAvatar =
        avatar != null &&
        avatar.isNotEmpty &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));
    final name = _publicReviewerName(review.reviewerDisplayName);
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
      child: hasAvatar
          ? null
          : Text(
              name == 'Anonymous' ? 'A' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
    );
  }
}
