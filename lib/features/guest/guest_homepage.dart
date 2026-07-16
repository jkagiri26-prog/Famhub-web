/// ============================================================
/// FAMHUB HOME — Guest landing page showcasing the ecosystem
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/guest/ = guest experience layer
///
/// ✅ Responsibilities:
///   - Showcase the entire ecosystem with attractive module cards
///   - Each module card includes short description and preview
///   - Navigate to real module pages in demo mode
///   - Guests land here after "Continue as Guest"
///   - Authenticated users land here for ecosystem overview
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No guest logic in feature widgets
///   - Pure presentation layer
///   - Uses DemoBanner for guest mode indicator
///   - Uses navigation to existing module pages (no duplication)
/// ============================================================
library famhub_app.features.guest.guest_homepage;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/shared/demo/demo_banner_widget.dart';

// Module page imports for direct navigation from guest home
import 'package:famhub_app/features/farm_management/presentation/pages/farm_dashboard_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_link_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_page.dart';
import 'package:famhub_app/features/ai_assistant/presentation/pages/ai_assistant_page.dart';

/// Module card data for the FAMHUB Home showcase
class _ModuleCardData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String demoLabel;

  const _ModuleCardData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.demoLabel = 'Demo',
  });
}

/// All ecosystem module cards shown on the guest home page
const List<_ModuleCardData> _allModuleCards = [
  _ModuleCardData(
    id: 'farm_management',
    title: 'Farm Management',
    description: 'Track crops, livestock, inventory, and farm operations with real-time insights',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF059669),
    demoLabel: '→ Demo Farm',
  ),
  _ModuleCardData(
    id: 'marketplace',
    title: 'Marketplace',
    description: 'Buy and sell farm products, inputs, and equipment directly',
    icon: Icons.store_outlined,
    color: Color(0xFF0891B2),
    demoLabel: '→ Demo Listings',
  ),
  _ModuleCardData(
    id: 'knowledge',
    title: 'Knowledge',
    description: 'Access agricultural guides, best practices, and training materials',
    icon: Icons.school_outlined,
    color: Color(0xFF7C3AED),
    demoLabel: '→ Demo Articles',
  ),
  _ModuleCardData(
    id: 'market_prices',
    title: 'Market Prices',
    description: 'Real-time price data for crops, livestock, and farm inputs',
    icon: Icons.trending_up_outlined,
    color: Color(0xFFD97706),
    demoLabel: '→ Demo Price Data',
  ),
  _ModuleCardData(
    id: 'finance',
    title: 'Finance',
    description: 'Access loans, insurance, savings, and financial management tools',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF059669),
    demoLabel: '→ Demo Financial Products',
  ),
  _ModuleCardData(
    id: 'logistics',
    title: 'Logistics',
    description: 'Manage transportation, storage, and supply chain coordination',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFFDC2626),
    demoLabel: '→ Demo Transport Requests',
  ),
  _ModuleCardData(
    id: 'community',
    title: 'Community',
    description: 'Connect with farmers, traders, and experts across the ecosystem',
    icon: Icons.people_outline,
    color: Color(0xFF0891B2),
    demoLabel: '→ Demo Posts',
  ),
  _ModuleCardData(
    id: 'ai_assistant',
    title: 'AI Assistant',
    description: 'Get intelligent recommendations, pest diagnosis, and farm insights',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFF7C3AED),
    demoLabel: '→ Demo Conversations',
  ),
  _ModuleCardData(
    id: 'weather',
    title: 'Weather',
    description: 'Local weather forecasts, historical data, and farming alerts',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFFD97706),
    demoLabel: '→ Demo Forecast',
  ),
  _ModuleCardData(
    id: 'reports',
    title: 'Reports',
    description: 'Generate detailed reports on production, sales, and operations',
    icon: Icons.assessment_outlined,
    color: Color(0xFFDC2626),
    demoLabel: '→ Demo Reports',
  ),
];

class GuestHomePage extends ConsumerWidget {
  const GuestHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGuest = ref.watch(isGuestProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Demo Banner (only for guests) ──
            if (isGuest)
              DemoBanner(
                onSignIn: () {
                  // Will be handled by session gate
                },
              ),

            // ── Scrollable Content ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Hero Section ──
                    _buildHeroSection(theme, colorScheme, isMobile),

                    // ── Ecosystem Modules Grid ──
                    _buildModulesSection(
                      context, theme, colorScheme, isMobile, isTablet, size, ref,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        isMobile ? 24 : 40,
        24,
        isMobile ? 24 : 32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.06),
            colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          // ── Logo ──
          Container(
            width: isMobile ? 64 : 80,
            height: isMobile ? 64 : 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              size: isMobile ? 32 : 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Text(
            'FAMHUB',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),

          // ── Tagline ──
          Text(
            'Your Complete Agricultural Platform',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Explore every part of the ecosystem.\nNo account required.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isTablet,
    Size size,
    WidgetRef ref,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              'Explore the Ecosystem',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          // ── Module Cards Grid ──
          if (isMobile)
            ..._allModuleCards.map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModuleCardWidget(
                  card: card,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => _openModuleDemo(context, card, ref),
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _allModuleCards
                  .map(
                    (card) => SizedBox(
                      width: isTablet
                          ? (size.width - 56) / 2
                          : (size.width - 56) / 3,
                      child: _ModuleCardWidget(
                        card: card,
                        colorScheme: colorScheme,
                        theme: theme,
                        onTap: () => _openModuleDemo(context, card, ref),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  /// Navigate to the appropriate module page based on card id.
  /// Guests see the same UI as authenticated users — only the
  /// repository (demo vs real) differs.
  void _openModuleDemo(
    BuildContext context,
    _ModuleCardData card,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    switch (card.id) {
      case 'farm_management':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Farm Management'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const FarmManagementPage(),
            ),
          ),
        );
        break;

      case 'marketplace':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Marketplace'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const MarketplacePage(),
            ),
          ),
        );
        break;

      case 'knowledge':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Knowledge Link'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const KnowledgeLinkPage(),
            ),
          ),
        );
        break;

      case 'finance':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Finance'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const FinancingPage(),
            ),
          ),
        );
        break;

      case 'logistics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Logistics'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const LogisticsPage(),
            ),
          ),
        );
        break;

      case 'ai_assistant':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('AI Assistant'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const AIAssistantPage(),
            ),
          ),
        );
        break;

      default:
        // For modules without dedicated pages yet, show a preview
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${card.title} — Coming soon! Explore other modules.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// MODULE CARD WIDGET
/// ─────────────────────────────────────────────────────────────
class _ModuleCardWidget extends StatelessWidget {
  final _ModuleCardData card;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ModuleCardWidget({
    required this.card,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              // ── Icon Container ──
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  card.icon,
                  size: 26,
                  color: card.color,
                ),
              ),
              const SizedBox(width: 16),

              // ── Text Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          card.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: card.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            card.demoLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: card.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Arrow Icon ──
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}