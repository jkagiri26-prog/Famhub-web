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
import 'package:famhub_app/features/auth/presentation/widgets/split_screen_hero.dart';

// Module page imports for direct navigation from FAMHUB Home
import 'package:famhub_app/features/farm_management/presentation/pages/farm_home_page.dart';
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

/// Impact statistic for the numbers section
class _ImpactStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _ImpactStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Marketplace listing preview data
class _MarketplacePreviewItem {
  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final Color color;

  const _MarketplacePreviewItem({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.color,
  });
}

/// Testimonial data
class _Testimonial {
  final String quote;
  final String name;
  final String role;
  final String location;
  final Color avatarColor;

  const _Testimonial({
    required this.quote,
    required this.name,
    required this.role,
    required this.location,
    required this.avatarColor,
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
    title: 'Knowledge Link',
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

/// Impact statistics shown in the numbers section
const List<_ImpactStat> _impactStats = [
  _ImpactStat(
    value: '15,000+',
    label: 'Farmers Empowered',
    icon: Icons.people_alt_outlined,
    color: Color(0xFF059669),
  ),
  _ImpactStat(
    value: '120+',
    label: 'Markets Connected',
    icon: Icons.store_mall_directory_outlined,
    color: Color(0xFF0891B2),
  ),
  _ImpactStat(
    value: '2.5B+',
    label: 'Transactions Processed',
    icon: Icons.account_balance_outlined,
    color: Color.fromARGB(255, 145, 95, 231),
  ),
  _ImpactStat(
    value: '48+',
    label: 'Partner Counties',
    icon: Icons.location_on_outlined,
    color: Color(0xFFD97706),
  ),
];

/// Marketplace listings preview
const List<_MarketplacePreviewItem> _marketplacePreviews = [
  _MarketplacePreviewItem(
    title: 'Fresh Maize',
    subtitle: 'Premium quality, harvested this season',
    price: 'Ksh.3,500/bag',
    icon: Icons.eco_outlined,
    color: Color(0xFF059669),
  ),
  _MarketplacePreviewItem(
    title: 'Organic Tomatoes',
    subtitle: 'Farm-fresh, pesticide-free produce',
    price: 'ksh.1,500/crate',
    icon: Icons.spa_outlined,
    color: Color(0xFFDC2626),
  ),
  _MarketplacePreviewItem(
    title: 'Watermelon',
    subtitle: 'Sweet & juicy, direct from farm',
    price: 'Ksh.100/unit',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF0891B2),
  ),
];

/// Success stories / testimonials
const List<_Testimonial> _testimonials = [
  _Testimonial(
    quote: 'FAMHUB transformed how I sell my produce. I now reach buyers across three states without leaving my farm.',
    name: 'Henry Ochieng',
    role: 'Tomatoes Farmer',
    location: 'Kisumu county',
    avatarColor: Color(0xFF059669),
  ),
  _Testimonial(
    quote: 'The financing services helped me secure a loan to expand my poultry business. The process was seamless.',
    name: 'Amina Yusuf',
    role: 'Poultry Farmer',
    location: 'Kwale County',
    avatarColor: Color(0xFF7C3AED),
  ),
  _Testimonial(
    quote: 'As a trader, the real-time market prices and logistics tracking have been game-changers for my business.',
    name: 'Edith Kanini',
    role: 'Agricultural Trader',
    location: 'Machakos County',
    avatarColor: Color(0xFF0891B2),
  ),
  _Testimonial(
    quote: 'Our cooperative reduced post-harvest losses by 40% using FAMHUB\'s storage and logistics coordination.',
    name: 'Grace Mwangi',
    role: 'Cooperative Leader',
    location: 'Nakuru, Kenya',
    avatarColor: Color(0xFFD97706),
  ),
];

class FamhubHomePage extends ConsumerWidget {
  /// Optional callback for the exploration banner's "Sign In" button.
  /// When set, the banner's button uses this instead of the default session gate flow.
  final VoidCallback? onExploreSignIn;

  /// True when rendered inside UnifiedAppShellV2 (e.g. the /home route).
  /// The shell owns the Scaffold/chrome — the page renders body content only.
  final bool inShell;

  const FamhubHomePage({
    super.key,
    this.onExploreSignIn,
    this.inShell = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    final body = Column(
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
                // ════════════════════════════════════════════
                // SECTION 1: SPLIT-SCREEN HERO CAROUSEL
                // Auth CTAs (Get Started / Explore as Guest) hidden for
                // authenticated users; the carousel always displays.
                // ════════════════════════════════════════════
                _buildHeroSection(
                    context, theme, colorScheme, isMobile, isAuthenticated),

                // ════════════════════════════════════════════
                // SECTION 2: IMPACT NUMBERS (Count-up style)
                // ════════════════════════════════════════════
                _buildImpactSection(theme, colorScheme, isMobile, isTablet, size),

                // ════════════════════════════════════════════
                // SECTION 3: FAMHUB MODULES (2 vertical + scrollable)
                // ════════════════════════════════════════════
                _buildFamhubModulesSection(
                  context, theme, colorScheme, isMobile, isTablet, size,
                ),

                // ════════════════════════════════════════════
                // SECTION 4: MARKETPLACE LISTINGS PREVIEW
                // ════════════════════════════════════════════
                _buildMarketplacePreview(
                  context, theme, colorScheme, isMobile,
                ),

                // ════════════════════════════════════════════
                // SECTION 5: WHY CHOOSE FAMHUB
                // ════════════════════════════════════════════
                _buildWhyChooseSection(
                  theme, colorScheme, isMobile, isTablet, size,
                ),

                // ════════════════════════════════════════════
                // SECTION 6: SUCCESS STORIES / TESTIMONIALS
                // ════════════════════════════════════════════
                _buildTestimonialSection(
                  context, theme, colorScheme, isMobile,
                ),

                // ════════════════════════════════════════════
                // SECTION 7: FINAL CTA
                // (guest-only — Create Your Free Account)
                // ════════════════════════════════════════════
                if (!isAuthenticated)
                  _buildFinalCtaSection(
                    theme, colorScheme, isMobile,
                  ),

                // ════════════════════════════════════════════
                // SECTION 8: FOOTER
                // ════════════════════════════════════════════
                _buildFooterSection(
                  theme, colorScheme, isMobile, isTablet, size,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (inShell) {
      // Rendered inside UnifiedAppShellV2 — the shell owns the Scaffold
      // and SafeArea; no nested top-level chrome.
      return body;
    }
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(child: body),
    );
  }

  /// ── SECTION 2: IMPACT NUMBERS ──
  Widget _buildImpactSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isTablet,
    Size size,
  ) {
    final minCardWidth = isMobile ? 140.0 : 170.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: colorScheme.surface,
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
          itemCount: _impactStats.length,
          separatorBuilder: (_, __) => Container(
            width: 1,
            height: 36,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final stat = _impactStats[index];
            return SizedBox(
              width: minCardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stat.icon, size: 16, color: stat.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          stat.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: stat.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ── SECTION 3: FAMHUB MODULES ──
  /// First two modules are displayed vertically (stacked).
  /// The rest are shown in a horizontally scrollable row with compact cards.
  Widget _buildFamhubModulesSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isTablet,
    Size size,
  ) {
    // First two modules (featured) — displayed prominently
    final featuredModules = _allModuleCards.take(2).toList();
    // Remaining modules — shown in horizontal scroll
    final scrollModules = _allModuleCards.skip(2).toList();

    // On mobile, if there are few modules, just show a grid
    final cardWidth = isMobile
        ? size.width * 0.7
        : isTablet
            ? 280.0
            : 240.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 24 : 40,
        isMobile ? 16 : 24,
        isMobile ? 24 : 40,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Explore the Ecosystem',
            style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need to thrive in agriculture',
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isMobile ? 20 : 28),

          // ── Featured modules (first 2) — vertical stack ──
          ...featuredModules.map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleCardWidget(
                card: card,
                colorScheme: colorScheme,
                theme: theme,
                onTap: () => _openModule(context, card),
              ),
            ),
          ),

          SizedBox(height: isMobile ? 16 : 20),

          // ── Section label for scrollable modules ──
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'More Services',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // ── Scrollable horizontal row ──
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: scrollModules.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final card = scrollModules[index];
                return SizedBox(
                  width: cardWidth,
                  child: _CompactModuleCard(
                    card: card,
                    colorScheme: colorScheme,
                    theme: theme,
                    onTap: () => _openModule(context, card),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ── SECTION 4: MARKETPLACE LISTINGS PREVIEW ──
  Widget _buildMarketplacePreview(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 24 : 40,
        isMobile ? 16 : 24,
        isMobile ? 24 : 40,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with action
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marketplace Listings',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fresh produce, verified sellers, fair prices',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openModule(context, _allModuleCards.firstWhere((c) => c.id == 'marketplace')),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Preview cards
          ..._marketplacePreviews.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MarketplacePreviewCard(
                item: item,
                colorScheme: colorScheme,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── SECTION 5: WHY CHOOSE FAMHUB ──
  Widget _buildWhyChooseSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isTablet,
    Size size,
  ) {
    const items = <_WhyChooseItem>[
      _WhyChooseItem(
        icon: Icons.verified_outlined,
        title: 'Trusted & Verified',
        description: 'Every user, product, and transaction is verified for your peace of mind.',
        color: Color(0xFF059669),
      ),
      _WhyChooseItem(
        icon: Icons.phone_iphone_outlined,
        title: 'Works Offline-First',
        description: 'Access critical features even without internet. Syncs when you reconnect.',
        color: Color(0xFF0891B2),
      ),
      _WhyChooseItem(
        icon: Icons.language_outlined,
        title: 'Multi-Lingual',
        description: 'Available in English, French, Swahili, and more local languages.',
        color: Color(0xFF7C3AED),
      ),
      _WhyChooseItem(
        icon: Icons.people_outline,
        title: 'For Everyone',
        description: 'Designed for farmers, traders, cooperatives, and agribusinesses of all sizes.',
        color: Color(0xFFD97706),
      ),
      _WhyChooseItem(
        icon: Icons.security_outlined,
        title: 'Secure Transactions',
        description: 'End-to-end encrypted payments, contracts, and data protection.',
        color: Color(0xFFDC2626),
      ),
      _WhyChooseItem(
        icon: Icons.support_outlined,
        title: '24/7 Support',
        description: 'Dedicated support team available in multiple languages via chat and phone.',
        color: Color(0xFF059669),
      ),
    ];

    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 32 : 48,
        isMobile ? 16 : 24,
        isMobile ? 32 : 48,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Why Choose FAMHUB?',
            style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Built for the African agricultural ecosystem',
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isMobile ? 20 : 28),

          // Grid
          ...List.generate(
            (items.length / crossAxisCount).ceil(),
            (rowIndex) {
              final start = rowIndex * crossAxisCount;
              final end = (start + crossAxisCount).clamp(0, items.length);
              final rowItems = items.sublist(start, end);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: rowItems
                      .map(
                        (item) => Expanded(
                          child: _WhyChooseCard(
                            item: item,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// ── SECTION 6: SUCCESS STORIES / TESTIMONIALS ──
  Widget _buildTestimonialSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 32 : 48,
        isMobile ? 16 : 24,
        isMobile ? 32 : 48,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Success Stories',
            style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hear from our community members',
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isMobile ? 20 : 28),

          // Testimonial cards
          SizedBox(
            height: isMobile ? 280 : 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: _testimonials.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final testimonial = _testimonials[index];
                return SizedBox(
                  width: isMobile ? size.width * 0.8 : 380,
                  child: _TestimonialCard(
                    testimonial: testimonial,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ── SECTION 7: FINAL CALL-TO-ACTION ──
  Widget _buildFinalCtaSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 40 : 64,
        isMobile ? 16 : 24,
        isMobile ? 40 : 64,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rocket_launch_rounded,
            size: 48,
            color: colorScheme.onPrimary,
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            'Ready to Transform Your\nAgricultural Journey?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 22 : 32,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimary,
              height: 1.2,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Join thousands of farmers, traders, and agribusinesses\nalready growing with FAMHUB.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          ElevatedButton.icon(
            onPressed: onExploreSignIn,
            icon: const Icon(Icons.person_add_outlined, size: 20),
            label: Text(
              'Create Your Free Account',
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.primary,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 28 : 36,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          TextButton(
            onPressed: () {
              // Scroll back to explore modules
            },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
            child: const Text(
              'Explore first — no account needed',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// ── SECTION 8: FOOTER ──
  Widget _buildFooterSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isTablet,
    Size size,
  ) {
    final columns = isMobile ? 1 : (isTablet ? 2 : 4);
    const footerLinks = <_FooterLinkGroup>[
      _FooterLinkGroup(
        title: 'Platform',
        links: ['Marketplace', 'Farm Management', 'Finance', 'Logistics', 'Knowledge'],
      ),
      _FooterLinkGroup(
        title: 'Company',
        links: ['About Us', 'Careers', 'Blog', 'Press Kit', 'Contact'],
      ),
      _FooterLinkGroup(
        title: 'Support',
        links: ['Help Center', 'FAQs', 'Community Forum', 'Report Issue', 'Status'],
      ),
      _FooterLinkGroup(
        title: 'Legal',
        links: ['Privacy Policy', 'Terms of Service', 'Cookie Policy', 'Data Processing', 'Licenses'],
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 32 : 48,
        isMobile ? 16 : 24,
        isMobile ? 16 : 24,
      ),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.agriculture_rounded,
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'FAMHUB',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Link columns
          ...List.generate(
            (footerLinks.length / columns).ceil(),
            (rowIndex) {
              final start = rowIndex * columns;
              final end = (start + columns).clamp(0, footerLinks.length);
              final rowLinks = footerLinks.sublist(start, end);

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowLinks
                      .map(
                        (group) => Expanded(
                          child: _FooterLinkGroupWidget(
                            group: group,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),

          // Divider
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          SizedBox(height: isMobile ? 12 : 16),

          // Bottom bar
          Row(
            children: [
              Expanded(
                child: Text(
                  '© 2025 FAMHUB. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Row(
                children: [
                  _SocialIcon(icon: Icons.facebook_outlined, onTap: () {}),
                  const SizedBox(width: 8),
                  _SocialIcon(icon: Icons.alternate_email_outlined, onTap: () {}),
                  const SizedBox(width: 8),
                  _SocialIcon(icon: Icons.videocam_outlined, onTap: () {}),
                ],
              ),
            ],
          ),

          SizedBox(height: isMobile ? 16 : 24),
        ],
      ),
    );
  }

  /// ── PREMIUM SPLIT-SCREEN HERO ──
  /// Uses SplitScreenHero which always renders as a horizontal
  /// 30/70 split — adapts font sizes and spacing on narrow screens.
  Widget _buildHeroSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile,
    bool isAuthenticated,
  ) {
    final size = MediaQuery.of(context).size;
    
    // Compact hero carousel height - fixed for better visual balance
    const heroHeight = 200.0;

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: ClipRRect(
        borderRadius: isMobile
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : BorderRadius.zero,
        child: SplitScreenHero(
          // Auth CTAs are hidden for authenticated users; the hero
          // carousel itself still displays for everyone.
          onGetStarted: isAuthenticated
              ? null
              : () {
                  // "Get Started" triggers sign in via the exploration banner's callback
                  onExploreSignIn?.call();
                },
          onExploreAsGuest: isAuthenticated
              ? null
              : () {
                  // Already exploring — no action needed
                },
        ),
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
              body: const FarmHomePage(),
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
            content: Text('${card.title} — Explore other services while we prepare more.'),
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
/// MODULE CARD WIDGET (Full-width)
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

/// ─────────────────────────────────────────────────────────────
/// COMPACT MODULE CARD (Horizontal scroll variant)
/// ─────────────────────────────────────────────────────────────
class _CompactModuleCard extends StatelessWidget {
  final _ModuleCardData card;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  const _CompactModuleCard({
    required this.card,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(card.icon, size: 18, color: card.color),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// IMPACT STAT CARD
/// ─────────────────────────────────────────────────────────────
class _ImpactStatCard extends StatelessWidget {
  final _ImpactStat stat;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _ImpactStatCard({
    required this.stat,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stat.color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 28, color: stat.color),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: stat.color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// MARKETPLACE PREVIEW CARD
/// ─────────────────────────────────────────────────────────────
class _MarketplacePreviewCard extends StatelessWidget {
  final _MarketplacePreviewItem item;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _MarketplacePreviewCard({
    required this.item,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Product icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 24, color: item.color),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Price
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.price,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// WHY CHOOSE ITEM DATA
/// ─────────────────────────────────────────────────────────────
class _WhyChooseItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _WhyChooseItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

/// ─────────────────────────────────────────────────────────────
/// WHY CHOOSE CARD
/// ─────────────────────────────────────────────────────────────
class _WhyChooseCard extends StatelessWidget {
  final _WhyChooseItem item;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _WhyChooseCard({
    required this.item,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 22, color: item.color),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// TESTIMONIAL CARD
/// ─────────────────────────────────────────────────────────────
class _TestimonialCard extends StatelessWidget {
  final _Testimonial testimonial;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _TestimonialCard({
    required this.testimonial,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote mark
          Icon(
            Icons.format_quote_rounded,
            size: 36,
            color: testimonial.avatarColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 4),
          // Quote text
          Expanded(
            child: Text(
              testimonial.quote,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Author info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: testimonial.avatarColor.withValues(alpha: 0.2),
                child: Text(
                  testimonial.name.isNotEmpty
                      ? testimonial.name[0]
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: testimonial.avatarColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimonial.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${testimonial.role} · ${testimonial.location}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// FOOTER LINK GROUP
/// ─────────────────────────────────────────────────────────────
class _FooterLinkGroup {
  final String title;
  final List<String> links;

  const _FooterLinkGroup({
    required this.title,
    required this.links,
  });
}

/// ─────────────────────────────────────────────────────────────
/// FOOTER LINK GROUP WIDGET
/// ─────────────────────────────────────────────────────────────
class _FooterLinkGroupWidget extends StatelessWidget {
  final _FooterLinkGroup group;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _FooterLinkGroupWidget({
    required this.group,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...group.links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () {},
              child: Text(
                link,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// SOCIAL ICON
/// ─────────────────────────────────────────────────────────────
class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SocialIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
