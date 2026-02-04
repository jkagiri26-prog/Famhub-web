import 'package:flutter/material.dart';

/// FAMHUB Module: ProfilePage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Style: Clean, High-Trust UI for Farmers/Traders.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      // Betpawa Rule: 16.0 horizontal padding, minimal top
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Header: Identity & Verification
            _buildProfileHeader(primaryGreen),
            const SizedBox(height: 24),

            // Metrics Grid (Farm Performance/Trust Score)
            _buildMetricsRow(),
            const SizedBox(height: 32),

            // Action List
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ACCOUNT SETTINGS",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingTile(Icons.verified_user_outlined, "KYC Verification", "Level 2 Verified", Colors.blue),
            _buildSettingTile(Icons.account_balance_wallet_outlined, "Payment Methods", "MPESA, Bank", Colors.black87),
            _buildSettingTile(Icons.history, "Transaction History", "View all receipts", Colors.black87),
            _buildSettingTile(Icons.language, "Language", "English (KE)", Colors.black87),
            
            const SizedBox(height: 32),
            
            // Logout Action
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 100), // BottomNav Clearance
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color primary) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: primary.withValues(alpha: 0.1),
              child: Icon(Icons.person, size: 50, color: primary),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 12),
        const Text("Samuel Karanja", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("Farmer ID: FH-99283", style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        _metricItem("Farm Size", "4.5 Acres"),
        const SizedBox(width: 12),
        _metricItem("Trust Score", "98%"),
      ],
    );
  }

  Widget _metricItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () {},
      ),
    );
  }
}