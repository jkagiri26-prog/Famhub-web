/// ============================================================
/// AGRI CONNECT — CONVERSATION VIEW (EMBEDDED CHAT)
/// ============================================================
///
/// Reusable message list + composer. Used both standalone (wrapped in a
/// Scaffold by ConversationPage) and embedded (community Chat tab).
/// Sender identity is backend-enforced; `isMine` is only a display concern.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/message.dart';
import '../../domain/enums/messaging_enums.dart';
import '../../domain/enums/safety_enums.dart';
import '../../application/providers/messaging_provider.dart';
import '../../application/providers/agri_connect_providers.dart';
import 'message_bubble.dart';
import 'report_sheet.dart';

class ConversationView extends ConsumerStatefulWidget {
  final String conversationId;

  const ConversationView({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<ConversationView> {
  final _composerController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myProfileId = ref.watch(agriConnectProfileIdProvider);

    return Column(
      children: [
        Expanded(child: _messages(context, myProfileId)),
        _composer(context),
      ],
    );
  }

  Widget _messages(BuildContext context, String? myProfileId) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load messages.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(messagesProvider(widget.conversationId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet. Say hello!'));
        }
        return ListView.builder(
          reverse: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMine =
                myProfileId != null && message.senderProfileId == myProfileId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MessageBubble(
                message: message,
                isMine: isMine,
                onReport: () => showAgriReportSheet(
                  context,
                  ref,
                  targetType: ReportTargetType.message,
                  targetId: message.id,
                ),
                onEdit: isMine ? () => _editMessage(context, message) : null,
                onDelete: isMine
                    ? () => _deleteMessage(context, message)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composerController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final body = _composerController.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingControllerProvider.notifier)
          .sendMessage(
            conversationId: widget.conversationId,
            type: MessageType.text,
            body: body,
          );
      _composerController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editMessage(BuildContext context, Message message) async {
    final controller = TextEditingController(text: message.body ?? '');
    final newBody = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBody == null || newBody.isEmpty) return;
    try {
      await ref
          .read(messagingControllerProvider.notifier)
          .editMessage(
            conversationId: widget.conversationId,
            messageId: message.id,
            body: newBody,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not edit message: $e')));
    }
  }

  Future<void> _deleteMessage(BuildContext context, Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(messagingControllerProvider.notifier)
          .deleteMessage(
            conversationId: widget.conversationId,
            messageId: message.id,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete message: $e')));
    }
  }
}
