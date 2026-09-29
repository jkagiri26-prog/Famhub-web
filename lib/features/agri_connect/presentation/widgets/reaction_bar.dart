/// ============================================================
/// AGRI CONNECT — REACTION BAR
/// ============================================================
///
/// Renders one-reaction-per-user reactions (UPSERT semantics handled in the
/// data layer). Tapping the active emoji removes it; tapping another replaces.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../domain/entities/reaction_summary.dart';

const List<String> kAgriReactions = ['👍', '❤️', '🙏', '🎉', '💡', '👏'];

class ReactionBar extends StatelessWidget {
  final ReactionSummary summary;
  final ValueChanged<String> onReact;
  final VoidCallback? onRemove;

  const ReactionBar({
    super.key,
    required this.summary,
    required this.onReact,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.counts.isEmpty && !summary.hasReacted) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];
    for (final emoji in kAgriReactions) {
      final count = summary.counts[emoji] ?? 0;
      if (count == 0 && summary.myReaction != emoji) continue;
      chips.add(
        InkWell(
          onTap: () {
            if (summary.myReaction == emoji) {
              onRemove?.call();
            } else {
              onReact(emoji);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: summary.myReaction == emoji
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: summary.myReaction == emoji
                    ? Colors.blue.shade200
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
