/// ============================================================
/// AI ASSISTANT PAGE (ENTERPRISE PHASE 10)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/ai_assistant/presentation/pages/ = AI assistant
///
/// ✅ Responsibilities:
///   - AI capabilities discovered from AIProviderDescriptors
///   - No module-specific AI code
///   - Each module registers its own AI capabilities
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - AI providers registered by each module
///   - Discovery-based: user sees all available AI capabilities
///   - No hardcoded AI feature lists
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (providers) {
          if (providers.isEmpty) {
            return _buildEmptyState(theme);
          }

          return Column(
            children: [
              // ── Chat / Query Input ──
              _buildQueryArea(theme),

              // ── Available AI Capabilities ──
              Expanded(
                child: Padding(
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQueryArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Ask AI anything...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.auto_awesome, color: Colors.purple.shade300),
          suffixIcon: IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed: () {},
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        style: theme.textTheme.bodyLarge,
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
              'AI features will appear here when enabled by modules.',
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
