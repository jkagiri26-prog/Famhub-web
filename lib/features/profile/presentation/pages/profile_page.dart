import 'package:flutter/material.dart';

import '../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../shared/widgets/headers/module_header_widget.dart';
import '../../../shared/widgets/headers/section_header_widget.dart';
import '../../../shared/widgets/cards/stats_card_widget.dart';
import '../../../shared/widgets/layout/section_container_widget.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapperWidget(
      child: Column(
        children: [
          const SizedBox(height: 12),

          /// HEADER
          ModuleHeaderWidget(
            title: "Profile",
            subtitle: "Identity ? Trust ? Farm Account",
            trailingIcon: Icons.settings,
            onTrailingTap: () {},
          ),

          const SizedBox(height: 20),

          /// PROFILE CARD
          SectionContainerWidget(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: primary.withOpacity(0.1),
                  child: Icon(Icons.person, size: 42, color: primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Samuel Karanja",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Farmer ID: FH-99283",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// METRICS
          Row(
            children: const [
              Expanded(
                child: StatsCardWidget(
                  title: "Farm Size",
                  value: "4.5 Acres",
                  icon: Icons.agriculture,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: StatsCardWidget(
                  title: "Trust Score",
                  value: "98%",
                  icon: Icons.verified,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// SETTINGS HEADER
          const SectionHeaderWidget(title: "Account Settings"),

          const SizedBox(height: 12),

          /// SETTINGS LIST (TEMP SIMPLE CARDS FOR NOW)
          _ProfileSettingTile(
            icon: Icons.verified_user_outlined,
            title: "KYC Verification",
            subtitle: "Level 2 Verified",
          ),

          _ProfileSettingTile(
            icon: Icons.account_balance_wallet_outlined,
            title: "Payment Methods",
            subtitle: "MPESA, Bank",
          ),

          _ProfileSettingTile(
            icon: Icons.history,
            title: "Transaction History",
            subtitle: "View all receipts",
          ),

          const SizedBox(height: 20),

          /// LOGOUT
          SectionContainerWidget(
            child: TextButton(
              onPressed: () {},
              child: const Text(
                "LOG OUT",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// LOCAL (NOT SHARED YET - PROFILE SPECIFIC)
class _ProfileSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}