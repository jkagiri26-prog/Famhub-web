/// ============================================================
/// AGRI CONNECT — MESSAGE BUBBLE
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/reaction_summary.dart';
import '../../application/providers/messaging_provider.dart';
import '../format.dart';
import 'reaction_bar.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final bool isMine;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onReport,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final reactionsAsync = ref.watch(messageReactionsProvider(message.id));
    final summary = reactionsAsync.value ?? const ReactionSummary();

    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine ? primary : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMine ? 14 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 14),
              ),
              border: isMine ? null : Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.isDeleted)
                  Text(
                    'This message was deleted.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: isMine ? Colors.white70 : Colors.grey.shade500,
                    ),
                  )
                else ...[
                  if (message.type.isMedia)
                    _mediaPlaceholder(context)
                  else
                    Text(
                      message.body ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: textColor,
                      ),
                    ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agriTimeAgo(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine ? Colors.white70 : Colors.grey.shade500,
                      ),
                    ),
                    if (message.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        'edited',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine ? Colors.white70 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!message.isDeleted) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ReactionBar(
                summary: summary,
                onReact: (emoji) => ref
                    .read(messagingControllerProvider.notifier)
                    .react(messageId: message.id, reaction: emoji),
                onRemove: () => ref
                    .read(messagingControllerProvider.notifier)
                    .removeReaction(message.id),
              ),
            ),
            if (isMine && (onEdit != null || onDelete != null))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      _action(context, Icons.edit_outlined, 'Edit', onEdit!),
                    if (onDelete != null)
                      _action(
                        context,
                        Icons.delete_outline,
                        'Delete',
                        onDelete!,
                      ),
                    if (onReport != null)
                      _action(
                        context,
                        Icons.flag_outlined,
                        'Report',
                        onReport!,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _mediaPlaceholder(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          message.type.label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
