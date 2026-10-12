import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

import '../widgets/credit_health_card_widget.dart';
import '../widgets/financial_partner_card_widget.dart';
import '../widgets/loan_offer_card_widget.dart';
import 'financing_catalogue_page.dart';
import 'financing_management_page.dart';

/// FAMHUB Module: FinancingPage
///
/// Architecture Compliance:
/// - No Scaffold
/// - No AppBar
/// - No Drawer
/// - No BottomNavigationBar
/// - Uses ResponsiveWrapper
/// - Uses shared headers
/// - Uses module-specific finance widgets
/// - Pure UI only (no backend logic)
///
/// This page acts as:
/// Finance + Credit + Insurance + SACCO + Lending Hub

class FinancingPage extends StatefulWidget {
  const FinancingPage({super.key});

  @override
  State<FinancingPage> createState() => _FinancingPageState();
}

class _FinancingPageState extends State<FinancingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int selectedPartnerTab = 0;

  final List<String> partnerTabs = const [
    'Banks',
    'SACCOs',
    'Insurance',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// MODULE HEADER
          const ModuleHeaderWidget(
            title: 'Agri-Finance Hub',
            subtitle:
                'Loans • SACCOs • Insurance • Input Financing',
            trailingIcon: Icons.account_balance_outlined,
          ),

          const SizedBox(height: 20),

          /// PHASE 1 CATALOGUE ENTRIES
          Row(
            children: [
              Expanded(
                child: _CatalogueEntryCard(
                  title: 'Browse catalogue',
                  subtitle: 'Verified partners and their published products',
                  icon: Icons.storefront_outlined,
                  onTap: () => Navigator.of(context)
                      .push(FinancingCataloguePage.route()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CatalogueEntryCard(
                  title: 'Manage catalogue',
                  subtitle: 'Providers, verification and product lifecycle',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () => Navigator.of(context)
                      .push(FinancingManagementPage.route()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          /// CREDIT HEALTH
          const CreditHealthCardWidget(),

          const SizedBox(height: 24),

          /// PARTNER SECTION
          const SectionHeaderWidget(
            title: 'Integrated Financial Partners',
          ),

          const SizedBox(height: 14),

          _buildPartnerTabs(),

          const SizedBox(height: 14),

          _buildPartnerSection(),

          const SizedBox(height: 24),

          /// LOAN OFFERS
          const SectionHeaderWidget(
            title: 'Active Loan Offers',
          ),

          const SizedBox(height: 12),

          const LoanOfferCardWidget(
            title: 'Pre-Season Input Loan',
            provider: 'Apollo Agriculture',
            amount: 'KSh 25,000',
            interest: '5% Monthly',
            isPriority: true,
          ),

          const SizedBox(height: 12),

          const LoanOfferCardWidget(
            title: 'Emergency Harvest Credit',
            provider: 'FamHub Finance',
            amount: 'KSh 5,000',
            interest: 'Instant Approval',
            isPriority: false,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// -----------------------------------
  /// PARTNER TABS
  /// -----------------------------------

  Widget _buildPartnerTabs() {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          partnerTabs.length,
          (index) {
            final isActive = index == selectedPartnerTab;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedPartnerTab = index;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? primary.withOpacity(0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  partnerTabs[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive
                        ? primary
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// -----------------------------------
  /// PARTNER SECTION SWITCHER
  /// -----------------------------------

  Widget _buildPartnerSection() {
    switch (selectedPartnerTab) {
      case 0:
        return const Column(
          children: [
            FinancialPartnerCardWidget(
              title: 'Equity Bank',
              subtitle: 'Input Loans • Asset Financing',
              icon: Icons.account_balance_outlined,
            ),
            SizedBox(height: 12),
            FinancialPartnerCardWidget(
              title: 'Co-operative Bank',
              subtitle: 'Farmer Lending • Working Capital',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        );

      case 1:
        return const Column(
          children: [
            FinancialPartnerCardWidget(
              title: 'Mkulima SACCO',
              subtitle: 'Savings • Credit • Milk Payments',
              icon: Icons.groups_outlined,
            ),
            SizedBox(height: 12),
            FinancialPartnerCardWidget(
              title: 'AgriCoop SACCO',
              subtitle: 'Farmer Deposits • Seasonal Loans',
              icon: Icons.savings_outlined,
            ),
          ],
        );

      case 2:
        return const Column(
          children: [
            FinancialPartnerCardWidget(
              title: 'APA Insurance',
              subtitle: 'Crop Cover • Livestock Protection',
              icon: Icons.shield_outlined,
            ),
            SizedBox(height: 12),
            FinancialPartnerCardWidget(
              title: 'Jubilee Insurance',
              subtitle: 'Farm Asset Cover • Weather Index',
              icon: Icons.verified_user_outlined,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// Entry tile for one of the Phase 1 catalogue screens. Follows the
/// established financing card convention (white card, 14 radius, hairline
/// border) so it reads as part of the module.
class _CatalogueEntryCard extends StatelessWidget {
  const _CatalogueEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF256D3A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
