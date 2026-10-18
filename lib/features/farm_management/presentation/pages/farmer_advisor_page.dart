import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';

/// ============================================================
/// FARMER ADVISOR PAGE — shell assistant, agricultural capability
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/
///
/// Opened from the shell's existing AI Assistant button via
/// AssistantLauncherRegistry. Not reachable from a route of its own, so it
/// can never become a competing navigation destination.
///
/// Shows one advisory conversation. The context banner reflects the
/// [AssistantContext] resolved for the route captured when it opened.
///
/// Model output is always rendered as plain text. It is never parsed as
/// markup and never presented as a confirmed diagnosis.
/// ============================================================
class FarmerAdvisorPage extends ConsumerStatefulWidget {
  const FarmerAdvisorPage({super.key, required this.initialRoute});

  /// Router path captured by the shell when the assistant was opened.
  final String initialRoute;

  @override
  ConsumerState<FarmerAdvisorPage> createState() => _FarmerAdvisorPageState();
}

class _FarmerAdvisorPageState extends ConsumerState<FarmerAdvisorPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final String question = _controller.text;
    if (question.trim().isEmpty) return;
    _controller.clear();
    // Read at send time so the envelope is the one that applies right now.
    final AssistantContext context =
        ref.read(assistantContextProvider(widget.initialRoute));
    await ref
        .read(farmerAdvisorControllerProvider.notifier)
        .ask(question, assistantContext: context);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantContext assistantContext =
        ref.watch(assistantContextProvider(widget.initialRoute));
    final farmAiContext = ref.watch(farmAiContextProvider);
    final FarmerAdvisorState state =
        ref.watch(farmerAdvisorControllerProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    ref.listen<FarmerAdvisorState>(farmerAdvisorControllerProvider, (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'FAMHUB AI',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Everything readable is selectable. Flutter draws text onto a
              // canvas, so nothing is copyable unless the app opts in. The
              // composer below is deliberately outside this area — it owns
              // its own selection as an editable field.
              Expanded(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContextBanner(
                        assistantContext: assistantContext,
                        hasFarm: farmAiContext != null,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: state.isEmpty
                            ? const _EmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: state.messages.length +
                                    (state.isLoading ? 1 : 0),
                                itemBuilder: (BuildContext context, int index) {
                                  if (index == state.messages.length) {
                                    return const _TypingIndicator();
                                  }
                                  return _MessageBubble(
                                    message: state.messages[index],
                                  );
                                },
                              ),
                      ),
                      if (state.status == AdvisorStatus.failure) ...[
                        const SizedBox(height: 8),
                        _FailureBanner(
                          errorCode: state.lastErrorCode,
                          onRetry: state.canRetry
                              ? () => ref
                                    .read(farmerAdvisorControllerProvider
                                        .notifier)
                                    .retry()
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !state.isLoading,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 2000,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Ask about your crops or livestock…',
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send question',
                    child: IconButton.filled(
                      onPressed: state.isLoading ? null : _send,
                      tooltip: 'Send',
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SelectionArea(
                child: Text(
                  'Advice is generated and may be uncertain — it is not a '
                  'diagnosis and not a substitute for a qualified professional. '
                  'For serious animal illness, suspected poisoning, difficult '
                  'births, or a heavy crop outbreak, contact a county extension '
                  'officer, KALRO, or a qualified veterinary officer promptly. '
                  'FAMHUB does not contact or book anyone for you.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim strip showing what the assistant currently knows about where the
/// user is. Missing values are simply absent — nothing is invented.
class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.assistantContext, required this.hasFarm});

  final AssistantContext assistantContext;
  final bool hasFarm;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> labels = assistantContext.visibleLabels;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labels.isEmpty ? 'No page context' : labels.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
          if (hasFarm) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Your farm context is included with each question.',
              child: Icon(
                Icons.agriculture_outlined,
                size: 16,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture_outlined, size: 40, color: colors.primary),
            const SizedBox(height: 12),
            const Text(
              'Ask about your crops or livestock.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Describe what you are seeing and you will get practical, '
              'step-by-step guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AdvisorMessage message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool farmer = message.isFarmer;

    return Align(
      alignment: farmer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: farmer ? colors.primaryContainer : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: farmer ? null : Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: farmer ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            SizedBox(width: 8),
            Text('Thinking…', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.errorCode, required this.onRetry});

  final String? errorCode;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorCode == null
                  ? 'The assistant could not answer. Check your connection.'
                  : 'The assistant could not answer ($errorCode).',
              style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
