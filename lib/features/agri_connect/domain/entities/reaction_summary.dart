/// ============================================================
/// AGRI CONNECT — REACTION SUMMARY VALUE OBJECT
/// ============================================================
///
/// Lightweight representation of reactions on a post/message:
/// the per-emoji counts and the current user's own reaction.
/// There is exactly ONE reaction per user per target (UPSERT semantics).
/// ============================================================
library;

class ReactionSummary {
  final Map<String, int> counts;
  final String? myReaction;

  const ReactionSummary({this.counts = const {}, this.myReaction});

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  bool get hasReacted => myReaction != null && myReaction!.isNotEmpty;
}
