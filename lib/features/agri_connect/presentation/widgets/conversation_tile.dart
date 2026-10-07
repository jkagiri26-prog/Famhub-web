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
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final name = conversation.title ?? '${conversation.type.label} chat';

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: primary.withValues(alpha: 0.06),
        highlightColor: primary.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.10),
                  border: Border.all(color: primary.withValues(alpha: 0.18)),
                ),
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
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            agriTimeAgo(conversation.lastMessageAt!),
                            style: TextStyle(fontSize: 11, color: cs.outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.type.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
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
