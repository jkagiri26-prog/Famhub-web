import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';
import 'package:famhub_app/shared/widgets/cards/stats_card_widget.dart';

import '../widgets/referral_action_card_widget.dart';
import '../widgets/referral_milestone_card_widget.dart';
import '../widgets/referral_earning_tile_widget.dart';
import '../widgets/referral_user_tile_widget.dart';
import '../widgets/referral_leaderboard_tile_widget.dart';
import '../widgets/referral_withdraw_button_widget.dart';

class ReferralHubPage extends StatelessWidget {
  const ReferralHubPage({super.key});

  static const String referralCode = "FAM-772-HUB";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: ResponsiveWrapper(
        child: Column(
          children: [
            const SizedBox(height: 12),

            /// Shared Header
            ModuleHeaderWidget(
              title: 'Referral Hub',
              subtitle: 'Invite ? Earn ? Network Growth',
              trailingIcon: Icons.share_outlined,
              onTrailingTap: () {},
            ),

            const SizedBox(height: 16),

            /// Tabs
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Earnings'),
                Tab(text: 'My Referrals'),
                Tab(text: 'Leaderboard'),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(),
                  _EarningsTab(),
                  _ReferralsTab(),
                  _LeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
        return ListView(
      children: [
        ReferralActionCardWidget(
          referralCode: ReferralHubPage.referralCode,
        ),

        SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Total Referrals',
                value: '12',
                icon: Icons.group_add,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: 'Total Earned',
                value: 'KSh 2,400',
                icon: Icons.payments,
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        ReferralMilestoneCardWidget(),

        SizedBox(height: 16),

        ReferralWithdrawButtonWidget(),

        SizedBox(height: 80),
      ],
    );
  }
}

class _EarningsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final earnings = [
      {
        'title': 'Direct Referral: Brian O.',
        'amount': '+200',
        'date': 'Today, 10:45 AM',
        'isDebit': false,
      },
      {
        'title': 'Wallet Withdrawal',
        'amount': '-1,000',
        'date': 'Jan 25, 2026',
        'isDebit': true,
      },
    ];

    return ListView.builder(
      itemCount: earnings.length,
      itemBuilder: (context, index) {
        final item = earnings[index];

        return ReferralEarningTileWidget(
          title: item['title'] as String,
          amount: item['amount'] as String,
          date: item['date'] as String,
          isDebit: item['isDebit'] as bool,
        );
      },
    );
  }
}

class _ReferralsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = [
      {
        'name': 'Brian Omondi',
        'joined': 'Feb 05, 2026',
        'verified': true,
      },
      {
        'name': 'Sarah Chen',
        'joined': 'Feb 02, 2026',
        'verified': false,
      },
    ];

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];

        return ReferralUserTileWidget(
          name: user['name'] as String,
          joinedDate: user['joined'] as String,
          isVerified: user['verified'] as bool,
        );
      },
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rankings = [
      {
        'name': 'Kelvin K.',
        'rank': 1,
        'referrals': 45,
        'isMe': false,
      },
      {
        'name': 'You',
        'rank': 4,
        'referrals': 12,
        'isMe': true,
      },
    ];

    return ListView.builder(
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final item = rankings[index];

        return ReferralLeaderboardTileWidget(
          name: item['name'] as String,
          rank: item['rank'] as int,
          referrals: item['referrals'] as int,
          isCurrentUser: item['isMe'] as bool,
        );
      },
    );
  }
}
