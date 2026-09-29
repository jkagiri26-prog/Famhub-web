/// ============================================================
/// AGRI CONNECT — NEW CONVERSATION PAGE
/// ============================================================
///
/// Creates group / community conversations via `create_conversation`.
/// Direct chat is initiated from a member's profile (recipient-scoped).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/community.dart';
import '../../domain/enums/messaging_enums.dart';
import '../../application/providers/messaging_provider.dart';
import '../../application/providers/community_provider.dart';
import '../format.dart';
import 'conversation_page.dart';

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  ConversationType _type = ConversationType.group;
  final _titleController = TextEditingController();
  String? _communityId;
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final conversation = await ref
          .read(messagingControllerProvider.notifier)
          .createConversation(
            type: _type,
            title: _type == ConversationType.group
                ? _titleController.text.trim()
                : null,
            communityId: _communityId,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationPage(conversationId: conversation.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start conversation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('New Conversation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ConversationType>(
            segments: const [
              ButtonSegment(
                value: ConversationType.group,
                label: Text('Group'),
                icon: Icon(Icons.group_outlined),
              ),
              ButtonSegment(
                value: ConversationType.community,
                label: Text('Community'),
                icon: Icon(Icons.forum_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          if (_type == ConversationType.group) ...[
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Group name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else
            _communityPicker(context),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Start Conversation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityPicker(BuildContext context) {
    final communitiesAsync = ref.watch(myCommunitiesProvider);
    return communitiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Could not load your communities.'),
      data: (communities) {
        if (communities.isEmpty) {
          return const Text(
            'You are not a member of any communities yet.',
            style: TextStyle(color: Colors.grey),
          );
        }
        return Column(
          children: [
            for (final community in communities)
              RadioListTile<String>(
                value: community.id,
                groupValue: _communityId,
                title: Text(community.name),
                subtitle: Text(community.type.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _communityId = v),
              ),
          ],
        );
      },
    );
  }
}
