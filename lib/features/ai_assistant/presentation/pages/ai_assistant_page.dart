/// ============================================================
/// AI ASSISTANT PAGE (ENTERPRISE PHASE 10)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/ai_assistant/presentation/pages/ = AI assistant
///
/// ✅ Responsibilities:
///   - Send a prompt through the deployed `ai-gateway` Edge Function
///   - Show the full gateway diagnostic (output / code / message /
///     request_id / elapsed) so the chain can be verified end to end
///   - Optionally pin a provider via the backend's developer selector
///   - AI capabilities discovered from AIProviderDescriptors
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Provider routing, capability filtering and fallback stay backend-side
///   - No provider API keys on the client
///   - Discovery-based: user sees all available AI capabilities
///   - No hardcoded AI feature lists
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/providers/composition_providers.dart';

/// ============================================================
/// AI PROVIDERS PROVIDER
/// ============================================================
final aiProvidersProvider = FutureProvider<List<AIProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeContributionEngine.aiProviders(enabledModules: modules);
});

/// ============================================================
/// AI ASSISTANT PAGE
/// ============================================================
class AIAssistantPage extends ConsumerWidget {
  const AIAssistantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(aiProvidersProvider);

    return ShellPageContent(
      title: 'AI Assistant',
      actions: [
        IconButton(
          icon: Icon(Icons.history, color: Colors.grey.shade600),
          onPressed: () {},
          tooltip: 'History',
        ),
      ],
      child: Column(
        children: [
          // ── Gateway query + live diagnostic ──
          const _AiGatewayPanel(),

          // ── Available AI Capabilities ──
          Expanded(
            child: providersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (providers) {
                if (providers.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Capabilities',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: providers.length,
                          itemBuilder: (context, index) {
                            final provider = providers[index];
                            return _AICapabilityCard(provider: provider);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: Colors.purple.shade300),
            const SizedBox(height: 16),
            Text('AI Assistant',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('No AI capabilities are configured.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 16),
            Text(
              'AI features will appear here when enabled by services.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// AI GATEWAY PANEL
/// ============================================================
///
/// Sends one prompt to the `ai-gateway` Edge Function and renders the
/// gateway's own diagnostic. Nothing here routes, selects or falls back —
/// that is entirely backend-owned. The provider dropdown only forwards the
/// backend's developer selector header; it never chooses a provider locally.
/// ============================================================
class _AiGatewayPanel extends ConsumerStatefulWidget {
  const _AiGatewayPanel();

  @override
  ConsumerState<_AiGatewayPanel> createState() => _AiGatewayPanelState();
}

class _AiGatewayPanelState extends ConsumerState<_AiGatewayPanel> {
  final TextEditingController _controller = TextEditingController();

  /// `null` means "no selector header" — the gateway owns the decision.
  String? _providerSelector;
  bool _running = false;
  AiGatewayResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String prompt = _controller.text;
    if (prompt.trim().isEmpty || _running) return;

    setState(() {
      _running = true;
      _result = null;
    });

    final AiGatewayService service =
        AiGatewayService(SupabaseService.instance.client);
    final AiGatewayResult result = await service.complete(
      prompt: prompt,
      providerSelector: _providerSelector,
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProviderRow(theme),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_running,
            minLines: 1,
            maxLines: 4,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Ask AI anything...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.auto_awesome, color: Colors.purple.shade300),
              suffixIcon: IconButton(
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: theme.colorScheme.primary),
                onPressed: _running ? null : _send,
                tooltip: 'Send to AI gateway',
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            style: theme.textTheme.bodyLarge,
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _ResultCard(theme: theme, result: _result!),
          ],
        ],
      ),
    );
  }

  /// Backend-owned provider selector. "Auto" omits the header entirely.
  Widget _buildProviderRow(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.tune, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          'Provider',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _providerSelector,
            isDense: true,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Auto (gateway decides)'),
              ),
              for (final String selector in AiGatewayService.providerSelectors)
                DropdownMenuItem<String?>(
                  value: selector,
                  child: Text(selector),
                ),
            ],
            onChanged: _running
                ? null
                : (String? value) =>
                    setState(() => _providerSelector = value),
          ),
        ),
        const Spacer(),
        Text(
          'POST /functions/v1/${AiGatewayService.functionName}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontFamily: 'monospace',
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// RESULT CARD
/// ============================================================
///
/// Developer diagnostic: deliberately shows the raw gateway `code`,
/// `message` and `request_id`, because the purpose of this surface is
/// verifying the backend chain.
/// ============================================================
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.theme, required this.result});

  final ThemeData theme;
  final AiGatewayResult result;

  @override
  Widget build(BuildContext context) {
    final bool ok = result.succeeded;
    final Color color = ok ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok ? 'Gateway succeeded' : 'Gateway failed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                result.elapsedLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _kv(theme, 'HTTP status', result.statusCode?.toString() ?? '—'),
          _kv(theme, 'request_id', result.requestId ?? 'absent'),
          if (result.code != null) _kv(theme, 'error code', result.code!),
          if (ok) ...[
            const SizedBox(height: 8),
            SelectableText(
              result.output ?? '',
              style: theme.textTheme.bodyMedium,
            ),
          ] else if (result.message != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              result.message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade700,
              ),
            ),
          ],
          if (result.rawBody != null) ...[
            const SizedBox(height: 12),
            Text(
              'Raw response',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              result.rawBody!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// AI CAPABILITY CARD
/// ============================================================
class _AICapabilityCard extends StatelessWidget {
  final AIProviderContribution provider;

  const _AICapabilityCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final icon = _resolveCapabilityIcon(provider.capability);
    final color = _resolveCapabilityColor(provider.capability);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (provider.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      provider.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.capability.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveCapabilityIcon(String capability) {
    switch (capability) {
      case 'price_recommendation':
      case 'demand_forecast':
        return Icons.trending_up;
      case 'crop_advisor':
      case 'disease_detection':
        return Icons.health_and_safety;
      case 'weather_advice':
        return Icons.wb_sunny;
      case 'loan_eligibility':
      case 'cashflow_prediction':
        return Icons.account_balance;
      case 'knowledge_search':
      case 'document_qa':
        return Icons.school;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _resolveCapabilityColor(String capability) {
    switch (capability) {
      case 'price_recommendation':
      case 'demand_forecast':
        return Colors.blue;
      case 'crop_advisor':
      case 'disease_detection':
        return Colors.green;
      case 'weather_advice':
        return Colors.orange;
      case 'loan_eligibility':
      case 'cashflow_prediction':
        return Colors.indigo;
      case 'knowledge_search':
      case 'document_qa':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }
}
