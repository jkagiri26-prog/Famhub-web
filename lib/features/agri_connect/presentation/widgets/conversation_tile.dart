/// ============================================================
/// AGRI CONNECT — CONVERSATION TILE
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/enums/messaging_enums.dart';
import '../format.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;

  const ConversationTile({super.key, required this.conversation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final name = conversation.title ?? '${conversation.type.label} chat';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Icon(_icon(conversation), size: 20, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            agriTimeAgo(conversation.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(Conversation c) {
    switch (c.type) {
      case ConversationType.direct:
        return Icons.person_outline;
      case ConversationType.community:
        return Icons.forum_outlined;
      case ConversationType.group:
        return Icons.group_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }
}
