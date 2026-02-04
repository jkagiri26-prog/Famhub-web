import 'package:flutter/material.dart';

/// FAMHUB Module: AgribusinessPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
class AgribusinessPage extends StatefulWidget {
  const AgribusinessPage({super.key});

  @override
  State<AgribusinessPage> createState() => _AgribusinessPageState();
}

/// The State class must be defined outside the StatefulWidget
class _AgribusinessPageState extends State<AgribusinessPage> {
  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      // "Betpawa" spacing rule: 16.0 horizontal, minimal top padding
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agribusiness Hub',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              title: "Farm Enterprise Management",
              desc: "Plan and track your farming as a business.",
              icon: Icons.assignment_turned_in_outlined,
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              title: "Financial Ledger",
              desc: "Record expenses, sales, and profit margins.",
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String desc, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}