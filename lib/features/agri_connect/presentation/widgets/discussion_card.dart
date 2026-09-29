/// ============================================================
/// AGRI CONNECT — DISCUSSION CARD
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../format.dart';

class DiscussionCard extends StatelessWidget {
  final Discussion discussion;
  final VoidCallback? onTap;

  const DiscussionCard({super.key, required this.discussion, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discussion.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: primary.withValues(alpha: 0.7),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      discussion.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (discussion.isLocked)
                    Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: Colors.grey.shade500,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _tag(discussion.type.label, _typeColor(discussion.type)),
                  const SizedBox(width: 8),
                  Text(
                    agriTimeAgo(discussion.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metric(
                    Icons.chat_bubble_outline,
                    '${discussion.replyCount}',
                  ),
                  const SizedBox(width: 14),
                  _metric(Icons.visibility_outlined, '${discussion.viewCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(DiscussionType type) {
    switch (type) {
      case DiscussionType.question:
        return Colors.blue.shade700;
      case DiscussionType.announcement:
        return Colors.orange.shade700;
      case DiscussionType.poll:
        return Colors.purple.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
