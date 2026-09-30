/// ============================================================
/// AGRI CONNECT — CONVERSATION PAGE (CHAT)
/// ============================================================
///
/// Standalone chat screen. The reusable message list/composer live in
/// `ConversationView` (also used by the community Chat tab).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/messaging_provider.dart';
import '../widgets/conversation_view.dart';

class ConversationPage extends ConsumerWidget {
  final String conversationId;

  const ConversationPage({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(
      conversationDetailsProvider(conversationId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(conversationAsync.value?.title ?? 'Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ConversationView(conversationId: conversationId),
    );
  }
}
