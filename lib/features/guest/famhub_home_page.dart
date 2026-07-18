/// ============================================================
/// FAMHUB HOME — Public ecosystem showcase for all visitors
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/guest/ = guest/exploration experience layer
///
/// ✅ Responsibilities:
///   - Showcase the entire ecosystem with attractive module cards
///   - Each module card includes short description and invitation
///   - Navigate to real module pages (with sample/public data)
///   - All visitors (unauthenticated) land here after "Continue Exploring"
///   - Authenticated users land here for ecosystem overview
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No guest user profile — all visitors are anonymous
///   - No demo labels or "Demo Mode" distinctions on cards
///   - Uses the real module pages, only swapping data source
///   - Authentication prompt appears only on protected actions
///
/// ✅ ECOSYSTEM INCLUSIVITY:
///   - Serves all agricultural ecosystem participants:
///     Farmers, Traders, Buyers, Financial Institutions,
///     Logistics Providers, Agronomists, Cooperatives,
///     Processors, Exporters, Warehouse Operators, Investors
/// ============================================================
library famhub_app.features.guest.famhub_home_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/shared/demo/demo_banner_widget.dart';

// Module page imports for direct navigation from FAMHUB Home
import 'package:famhub_app/features/farm_management/presentation/pages/farm_dashboard_page.dart';
import 'package:famhub_app/features/marketplace/presentation/pages/marketplace_page.dart';
import 'package:famhub_app/features/knowledge_link/presentation/pages/knowledge_link_page.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_page.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_page.dart';
import 'package:famhub_app/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:famhub_app/features/opportunities/presentation/pages/opportunities_page.dart';
import 'package:famhub_app/features/agribusiness/presentation/pages/agribusiness_page.dart';
import 'package:famhub_app/features/agri_connect/presentation/pages/agri_connect_page.dart';
import 'package:famhub_app/features/analytics/presentation/pages/analytics_page.dart';

/// Module card data for the FAMHUB Home ecosystem showcase
class _ModuleCardData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _ModuleCardData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// All ecosystem module cards shown on the FAMHUB Home page.
/// Descriptions are written for a diverse agricultural audience
/// including farmers, traders, financial institutions, logistics
/// providers, cooperatives, exporters, and investors.
const List<_ModuleCardData> _allModuleCards = [
  _ModuleCardData(
    id: 'marketplace',
    title: 'Marketplace',
    description: 'Buy and sell agricultural products, inputs, and equipment. Connect with buyers, sellers, and traders across the value chain.',
    icon: Icons.store_outlined,
    color: Color(0xFF0891B2),
  ),
  _ModuleCardData(
    id: 'farm_management',
    title: 'Farm Management',
    description: 'Track crops, livestock, inventory, and operations. Ideal for farmers, agronomists, and farm managers.',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF059669),
  ),
  _ModuleCardData(
    id: 'finance',
    title: 'Finance',
    description: 'Access loans, insurance, savings, and financial tools for agricultural enterprises. Designed for farmers, cooperatives, and financial institutions.',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF0891B2),
  ),
  _ModuleCardData(
    id: 'logistics',
    title: 'Logistics',
    description: 'Manage transportation, storage, and supply chain coordination for agricultural goods. Essential for traders, transporters, and warehouse operators.',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFFDC2626),
  ),
  _ModuleCardData(
    id: 'agribusiness',
    title: 'Agribusiness',
    description: 'Manage business operations, sales, procurement, and enterprise analytics for agricultural businesses of all sizes.',
    icon: Icons.business_outlined,
    color: Color(0xFF7C3AED),
  ),
  _ModuleCardData(
    id: 'market_prices',
    title: 'Market Prices',
    description: 'Real-time and historical price data for crops, livestock, and inputs. Essential intelligence for traders, farmers, and investors.',
    icon: Icons.trending_up_outlined,
    color: Color(0xFFD97706),
  ),
  _ModuleCardData(
    id: 'knowledge',
    title: 'Knowledge',
    description: 'Access agricultural guides, best practices, market insights, and training materials for every role in the ecosystem.',
    icon: Icons.school_outlined,
    color: Color(0xFF7C3AED),
  ),
  _ModuleCardData(
    id: 'community',
    title: 'Community',
    description: 'Connect with farmers, traders, agronomists, buyers, and experts across the entire agricultural ecosystem.',
    icon: Icons.people_outline,
    color: Color(0xFF0891B2),
  ),
  _ModuleCardData(
    id: 'opportunities',
    title: 'Opportunities',
    description: 'Discover funding, partnership, training, and market opportunities across the agricultural value chain.',
    icon: Icons.rocket_launch_outlined,
    color: Color(0xFF059669),
  ),
  _ModuleCardData(
    id: 'ai_assistant',
    title: 'AI Assistant',
    description: 'Get intelligent recommendations, market analysis, pest diagnosis, and actionable insights for your agricultural operations.',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFF7C3AED),
  ),
  _ModuleCardData(
    id: 'agri_connect',
    title: 'AgriConnect',
    description: 'Network with stakeholders across the ecosystem — cooperatives, processors, exporters, and service providers.',
    icon: Icons.hub_outlined,
    color: Color(0xFFDC2626),
  ),
  _ModuleCardData(
    id: 'analytics',
    title: 'Analytics',
    description: 'Comprehensive data analysis, reporting, and business intelligence for informed decision-making at every level.',
    icon: Icons.analytics_outlined,
    color: Color(0xFF059669),
  ),
  _ModuleCardData(
    id: 'weather',
    title: 'Weather',
    description: 'Local forecasts, historical climate data, and agricultural alerts to support planning across all operations.',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFFD97706),
  ),
  _ModuleCardData(
    id: 'reports',
    title: 'Reports & Insights',
    description: 'Generate detailed reports on production, sales, market trends, and operational performance.',
    icon: Icons.assessment_outlined,
    color: Color(0xFFDC2626),
  ),
];

class FamhubHomePage extends ConsumerWidget {
  /// Optional callback for the exploration banner's "Sign In" button.
  /// When set, the banner's button uses this instead of the default session gate flow.
  final VoidCallback? onExploreSignIn;

  const FamhubHomePage({super.key, this.onExploreSignIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Exploration Banner (only for unauthenticated) ──
            if (!isAuthenticated)
              _ExplorationBanner(
                onSignIn: onExploreSignIn ?? () {
                  // Default: handled by session gate
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
                      context, theme, colorScheme, isMobile, isTablet, size,
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
            'The Agricultural Ecosystem',
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
                  onTap: () => _openModule(context, card),
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
                        onTap: () => _openModule(context, card),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  /// Navigate to the appropriate module page.
  /// Visitors open the real modules — only the data source differs.
  void _openModule(
    BuildContext context,
    _ModuleCardData card,
  ) {
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

      case 'opportunities':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Opportunities'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const OpportunitiesPage(),
            ),
          ),
        );
        break;

      case 'agribusiness':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Agribusiness'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const AgribusinessPage(),
            ),
          ),
        );
        break;

      case 'analytics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Analytics'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: const AnalyticsPage(),
            ),
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${card.title} — Explore other modules while we prepare more.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// EXPLORATION BANNER
/// ─────────────────────────────────────────────────────────────
///
/// A subtle banner at the top of FAMHUB Home for unauthenticated
/// visitors. Informs them they are browsing publicly and offers
/// a sign-in option without being intrusive.
class _ExplorationBanner extends StatelessWidget {
  final VoidCallback? onSignIn;

  const _ExplorationBanner({this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore_outlined,
            color: colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are exploring FAMHUB — no account needed',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
                    Text(
                      card.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
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
