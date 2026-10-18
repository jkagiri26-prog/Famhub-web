import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/features/auth/presentation/pages/sign_in_screen_page.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';

/// ============================================================
/// FARMER ADVISOR PAGE — shell assistant, agricultural capability
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/
///
/// Opened from the shell's existing AI Assistant button via
/// AssistantLauncherRegistry, from the FAMHUB home AI Assistant card, and
/// registered for the `/ai-assistant` route — one advisor page everywhere
/// the assistant is reachable, never two competing AI pages.
///
/// Shows one advisory conversation with a history sheet for saved threads
/// (open, start new, rename, delete). The context banner reflects the
/// [AssistantContext] resolved for the route captured when it opened.
///
/// Guests can open and read the page, but asking requires an account: a
/// persistent notice and a send-time prompt route them to sign up / log in,
/// and no question ever reaches the gateway without a signed-in session.
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
    // Guests may read the page and type, but asking (and the write that
    // follows) requires an account. The composer keeps their text.
    if (!ref.read(isAuthenticatedProvider)) {
      await _promptAuth();
      return;
    }
    _controller.clear();
    // Read at send time so the envelope is the one that applies right now.
    final AssistantContext context = ref.read(
      assistantContextProvider(widget.initialRoute),
    );
    await ref
        .read(farmerAdvisorControllerProvider.notifier)
        .ask(question, assistantContext: context);
    _scrollToBottom();
  }

  /// Explains why a guest cannot ask yet and offers the way in.
  Future<void> _promptAuth() async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign up or log in'),
        content: const Text(
          'Create an account or sign in to ask questions and keep your '
          'chat history on FAMHUB.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    _openAuth();
  }

  /// Opens the phone/OTP sign-in flow. On success the refreshed session
  /// flips [isAuthenticatedProvider], the notice disappears, and the
  /// conversation the guest was reading is still right there.
  void _openAuth() {
    final NavigatorState navigator = Navigator.of(context);
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreenPage(
          onAuthenticate:
              ({required String contact, required String otp}) async {
                try {
                  final OtpVerifyResult result = await AuthService().verifyOtp(
                    phone: contact,
                    token: otp,
                  );
                  if (!result.success) return false;
                  if (!mounted) return false;
                  await ref.read(sessionProvider.notifier).refresh();
                  if (mounted) navigator.pop();
                  return true;
                } catch (_) {
                  return false;
                }
              },
          onBack: () => navigator.pop(),
        ),
      ),
    );
  }

  void _startNewChat() {
    ref.read(farmerAdvisorControllerProvider.notifier).startNewChat();
    _controller.clear();
  }

  Future<void> _openHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) => const _HistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AssistantContext assistantContext = ref.watch(
      assistantContextProvider(widget.initialRoute),
    );
    final farmAiContext = ref.watch(farmAiContextProvider);
    final FarmerAdvisorState state = ref.watch(farmerAdvisorControllerProvider);
    final bool isGuest = !ref.watch(isAuthenticatedProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    ref.listen<FarmerAdvisorState>(farmerAdvisorControllerProvider, (_, __) {
      _scrollToBottom();
    });

    final Widget banner = _ContextBanner(
      assistantContext: assistantContext,
      hasFarm: farmAiContext != null,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _BrandBadge(size: 26),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (Rect bounds) =>
                  _brandGradient(colors).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'FAMHUB AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: _startNewChat,
          ),
        ],
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.6) ??
                      colors.primary,
                  colors.tertiary,
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Everything readable is selectable. Flutter draws text
                    // onto a canvas, so nothing is copyable unless the app
                    // opts in. The composer below is deliberately outside
                    // this area — it owns its own selection as an editable
                    // field, and interactive controls (suggestion chips,
                    // banners with buttons) sit outside it too.
                    SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [banner, const SizedBox(height: 12)],
                      ),
                    ),
                    Expanded(
                      child: state.isEmpty
                          ? _PremiumEmptyState(
                              onSuggest: (String suggestion) {
                                _controller.text = suggestion;
                              },
                            )
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    colors.primary.withValues(alpha: 0.05),
                                    colors.surface.withValues(alpha: 0.0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: SelectionArea(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        itemCount:
                                            state.messages.length +
                                            (state.isLoading ? 1 : 0),
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              if (index ==
                                                  state.messages.length) {
                                                return const _TypingIndicator();
                                              }
                                              return _MessageBubble(
                                                message: state.messages[index],
                                              );
                                            },
                                      ),
                                    ),
                                    if (state.status ==
                                        AdvisorStatus.failure) ...[
                                      const SizedBox(height: 8),
                                      _FailureBanner(
                                        errorCode: state.lastErrorCode,
                                        onRetry: state.canRetry
                                            ? () => ref
                                                  .read(
                                                    farmerAdvisorControllerProvider
                                                        .notifier,
                                                  )
                                                  .retry()
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (isGuest) ...[
                const SizedBox(height: 8),
                _GuestNotice(onOpenAuth: _openAuth),
              ],
              if (state.persistenceWarning) ...[
                const SizedBox(height: 8),
                _PersistenceBanner(
                  unsavedCount: state.unsavedMessageCount,
                  onRetry: () => ref
                      .read(farmerAdvisorControllerProvider.notifier)
                      .retryPersistence(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(1.3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            colors.primary.withValues(alpha: 0.55),
                            colors.tertiary.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _controller,
                          enabled: !state.isLoading,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 2000,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Ask about your crops or livestock…',
                            filled: true,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Send question',
                      child: IconButton.filled(
                        onPressed: state.isLoading ? null : _send,
                        tooltip: 'Send',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                        ),
                        icon: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectionArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient badge used as the assistant's mark. Deliberately a Container —
/// never a CircleAvatar or a network image.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _brandGradient(colors),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}

Gradient _brandGradient(ColorScheme colors) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      colors.primary,
      Color.lerp(colors.primary, colors.tertiary, 0.55) ?? colors.primary,
    ],
  );
}

/// Slim pill showing what the assistant currently knows about where the
/// user is. Missing values are simply absent — nothing is invented.
class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.assistantContext, required this.hasFarm});

  final AssistantContext assistantContext;
  final bool hasFarm;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> labels = assistantContext.visibleLabels;

    final Widget banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 16, color: colors.primary),
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
                Icons.auto_awesome_rounded,
                size: 16,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.primary.withValues(alpha: 0.55),
            colors.tertiary.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: banner,
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  static const List<String> _suggestions = <String>[
    "What's the weather forecast?",
    'When was my cow last vaccinated?',
    'Any maize listings in the market?',
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    top: 6,
                    right: 40,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: colors.tertiary.withValues(alpha: 0.85),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 38,
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: colors.primary.withValues(alpha: 0.75),
                    ),
                  ),
                  Positioned(
                    top: 44,
                    left: 24,
                    child: Icon(
                      Icons.eco_outlined,
                      size: 16,
                      color: colors.tertiary.withValues(alpha: 0.6),
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: _brandGradient(colors),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.5),
                          blurRadius: 42,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: colors.tertiary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ShaderMask(
              shaderCallback: (Rect bounds) =>
                  _brandGradient(colors).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'Ask about your crops or livestock.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Describe what you are seeing and you will get practical, '
              'step-by-step guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final String suggestion in _suggestions)
                  _SuggestionChip(
                    label: suggestion,
                    onTap: () => onSuggest(suggestion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.primary.withValues(alpha: 0.65),
            colors.tertiary.withValues(alpha: 0.45),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: colors.onSurface),
                ),
              ],
            ),
          ),
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

    final Widget bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      constraints: const BoxConstraints(maxWidth: 540),
      decoration: farmer
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.35) ??
                      colors.primary,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: farmer ? colors.onPrimary : colors.onSurface,
        ),
      ),
    );

    if (farmer) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 8, bottom: 5),
            decoration: BoxDecoration(
              gradient: _brandGradient(colors),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          Flexible(child: bubble),
        ],
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
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colors.onErrorContainer,
          ),
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

/// Visible, retryable report that messages have not reached storage yet.
/// Guests are told plainly that asking needs an account — never a dead
/// send button and never a silent no-op.
class _GuestNotice extends StatelessWidget {
  const _GuestNotice({required this.onOpenAuth});

  final VoidCallback onOpenAuth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sign up or log in to use the AI assistant.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: onOpenAuth,
            child: Text(
              'Sign up or log in',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistence failures are never silent.
class _PersistenceBanner extends StatelessWidget {
  const _PersistenceBanner({required this.unsavedCount, required this.onRetry});

  final int unsavedCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C26B)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unsavedCount == 1
                  ? '1 message is not saved to your history yet.'
                  : '$unsavedCount messages are not saved to your history yet.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry saving',
              style: TextStyle(color: Color(0xFFB45309)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing saved conversations with open / new / rename /
/// delete, including loading, failed and empty states.
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  /// Shows EVERY saved thread. Conversations are never locked to a module,
  /// route or entity — context labels are metadata only.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FarmerAdvisorState state = ref.watch(farmerAdvisorControllerProvider);
    final FarmerAdvisorController controller = ref.read(
      farmerAdvisorControllerProvider.notifier,
    );
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  gradient: _brandGradient(colors),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _BrandBadge(size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Past conversations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          controller.startNewChat();
                        },
                        icon: const Icon(Icons.add_comment_rounded, size: 16),
                        label: const Text('New chat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.openConversationFailed) ...[
                    _SheetNotice(
                      icon: Icons.error_outline_rounded,
                      color: colors.error,
                      text:
                          "Couldn't open that conversation. It may have been "
                          'deleted.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (state.managementError != null) ...[
                    _SheetNotice(
                      icon: Icons.error_outline_rounded,
                      color: colors.error,
                      text: state.managementError == 'rename_failed'
                          ? 'Could not rename that conversation.'
                          : 'Could not delete that conversation.',
                    ),
                    const SizedBox(height: 8),
                  ],
                  Flexible(child: _buildList(context, ref, controller, state)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    FarmerAdvisorController controller,
    FarmerAdvisorState state,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (state.historyStatus == AdvisorHistoryStatus.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text(
                'Loading your conversations…',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (state.historyStatus == AdvisorHistoryStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 34, color: colors.outline),
              const SizedBox(height: 10),
              const Text(
                "Couldn't load your conversations. Check your connection.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => controller.retryHistoryLoad(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.conversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 32),
              SizedBox(height: 10),
              Text(
                'No past conversations yet.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Ask a question to start one.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: state.conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (BuildContext context, int index) {
        final AssistantConversation conversation = state.conversations[index];
        final bool isActive = conversation.id == state.activeConversationId;
        return _ConversationTile(
          conversation: conversation,
          isActive: isActive,
          onOpen: () {
            Navigator.of(context).pop();
            controller.selectConversation(conversation.id);
          },
          onRename: () async {
            final String? title = await _promptRename(context, conversation);
            if (title != null) {
              await controller.renameConversation(conversation.id, title);
            }
          },
          onDelete: () async {
            final bool confirmed = await _confirmDelete(context, conversation);
            if (confirmed) {
              await controller.deleteConversation(conversation.id);
            }
          },
        );
      },
    );
  }
}

class _SheetNotice extends StatelessWidget {
  const _SheetNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final AssistantConversation conversation;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateTime activity =
        conversation.lastMessageAt ?? conversation.createdAt;

    return Material(
      color: isActive
          ? colors.primary.withValues(alpha: 0.1)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  gradient: isActive ? _brandGradient(colors) : null,
                  color: isActive
                      ? null
                      : colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive
                      ? Icons.auto_awesome_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: isActive
                      ? colors.onPrimary
                      : colors.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatActivity(activity),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Conversation options',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                onSelected: (String action) {
                  if (action == 'rename') {
                    onRename();
                  } else if (action == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatActivity(DateTime time) {
  final DateTime now = DateTime.now();
  final DateTime day = time;
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime that = DateTime(day.year, day.month, day.day);
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (that == today) {
    return '${day.hour.toString().padLeft(2, '0')}:'
        '${day.minute.toString().padLeft(2, '0')}';
  }
  if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (day.year == now.year) {
    return '${day.day} ${months[day.month - 1]}';
  }
  return '${day.day} ${months[day.month - 1]} ${day.year}';
}

Future<String?> _promptRename(
  BuildContext context,
  AssistantConversation conversation,
) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _RenameDialog(initial: conversation.title),
  );
}

Future<bool> _confirmDelete(
  BuildContext context,
  AssistantConversation conversation,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text(
          '"${conversation.title}" and its messages will be permanently '
          'removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  bool _hasText = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename conversation'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        onSubmitted: (_) => _submit(),
        onChanged: (String value) {
          final bool hasText = value.trim().isNotEmpty;
          if (hasText != _hasText) {
            setState(() => _hasText = hasText);
          }
        },
        decoration: const InputDecoration(
          hintText: 'Conversation name',
          counterText: '',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hasText ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
