import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReferralHubPage extends StatelessWidget {
  const ReferralHubPage({super.key});

  final String referralCode = "FAM-772-HUB";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // --- Global Header (Sticky) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
              child: _buildHeader(theme),
            ),
            
            // --- Navigation Tabs ---
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Earnings'),
                Tab(text: 'My Referrals'),
                Tab(text: 'Leaderboard'),
              ],
            ),

            // --- Populated Content ---
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(context, theme),
                  _buildEarningsTab(theme),
                  _buildReferralsTab(theme),
                  _buildLeaderboardTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. OVERVIEW: Summary & Quick Actions ---
  Widget _buildOverviewTab(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionCard(context, theme),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard('12', 'Total Referrals', Icons.group_add, theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Ksh 2,400', 'Total Earned', Icons.payments, theme)),
            ],
          ),
          const SizedBox(height: 24),
          _buildMilestoneCard(theme),
          const SizedBox(height: 24),
          _buildWithdrawButton(theme),
        ],
      ),
    );
  }

  // --- 2. EARNINGS: Detailed Transaction Log ---
  Widget _buildEarningsTab(ThemeData theme) {
    final List<Map<String, String>> earnings = [
      {'title': 'Direct Referral: Brian O.', 'amount': '+200', 'date': 'Today, 10:45 AM', 'type': 'credit'},
      {'title': 'Direct Referral: James M.', 'amount': '+200', 'date': 'Feb 04, 2026', 'type': 'credit'},
      {'title': 'Tier 2 Bonus: Sarah C.', 'amount': '+50', 'date': 'Feb 03, 2026', 'type': 'credit'},
      {'title': 'Milestone: 10 Refs reached', 'amount': '+500', 'date': 'Jan 30, 2026', 'type': 'bonus'},
      {'title': 'Wallet Withdrawal', 'amount': '-1,000', 'date': 'Jan 25, 2026', 'type': 'debit'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: earnings.length,
      itemBuilder: (context, index) {
        final item = earnings[index];
        bool isDebit = item['type'] == 'debit';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isDebit ? Colors.red.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  isDebit ? Icons.arrow_outward : Icons.south_west,
                  color: isDebit ? Colors.red : theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(item['date']!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Text(
                item['amount']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDebit ? Colors.red : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 3. MY REFERRALS: User Network ---
  Widget _buildReferralsTab(ThemeData theme) {
    final List<Map<String, String>> users = [
      {'name': 'Brian Omondi', 'joined': 'Feb 05, 2026', 'status': 'Verified'},
      {'name': 'Sarah Chen', 'joined': 'Feb 02, 2026', 'status': 'Pending'},
      {'name': 'James Mwangi', 'joined': 'Jan 28, 2026', 'status': 'Verified'},
      {'name': 'Alice Wambui', 'joined': 'Jan 25, 2026', 'status': 'Verified'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        bool isVerified = user['status'] == 'Verified';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(child: Text(user['name']![0])),
          title: Text(user['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Joined ${user['joined']}'),
          trailing: Chip(
            label: Text(user['status']!, style: const TextStyle(fontSize: 10)),
            backgroundColor: isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            side: BorderSide.none,
            labelStyle: TextStyle(color: isVerified ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  // --- 4. LEADERBOARD: Competition ---
  Widget _buildLeaderboardTab(ThemeData theme) {
    final List<Map<String, dynamic>> rankings = [
      {'name': 'Kelvin K.', 'refs': 45, 'rank': 1},
      {'name': 'Anita M.', 'refs': 38, 'rank': 2},
      {'name': 'Derrick L.', 'refs': 22, 'rank': 3},
      {'name': 'You', 'refs': 12, 'rank': 4},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final row = rankings[index];
        bool isMe = row['name'] == 'You';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isMe ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            leading: Text('#${row['rank']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            title: Text(row['name'], style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
            trailing: Text('${row['refs']} referrals', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // --- GLOBAL COMPONENTS ---

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Referral Hub', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text('Invite friends and grow your income.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Your Referral Code', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(referralCode, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Link'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: referralCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                },
                icon: const Icon(Icons.copy, color: Colors.white),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Silver Milestone (12/15)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 0.8, backgroundColor: theme.colorScheme.surfaceVariant, color: theme.colorScheme.primary, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Withdraw to M-Pesa'),
      ),
    );
  }
}