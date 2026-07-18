import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/cards/stats_card_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';
import 'package:famhub_app/core/session/session_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;

    return ResponsiveWrapper(
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
                    const Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: "Farm Size",
                  value: "4.5 Acres",
                  icon: Icons.agriculture,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: StatsCard(
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
          const _ProfileSettingTile(
            icon: Icons.verified_user_outlined,
            title: "KYC Verification",
            subtitle: "Level 2 Verified",
          ),

          const _ProfileSettingTile(
            icon: Icons.account_balance_wallet_outlined,
            title: "Payment Methods",
            subtitle: "MPESA, Bank",
          ),

          const _ProfileSettingTile(
            icon: Icons.history,
            title: "Transaction History",
            subtitle: "View all receipts",
          ),

          const SizedBox(height: 20),

                    /// LOGOUT
          SectionContainerWidget(
            child: TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(sessionProvider.notifier).signOut();
                }
              },
              child: const Text(
                "Sign Out",
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
