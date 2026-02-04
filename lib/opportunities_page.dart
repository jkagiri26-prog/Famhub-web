import 'package:flutter/material.dart';

/// FAMHUB Module: OpportunitiesPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Style: Betpawa-inspired high-density data grid.
class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      // Betpawa Rule: 16.0 horizontal padding
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agri-Opportunities',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tenders, grants, and training programs.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Featured "Hot" Opportunity
            _buildFeaturedBanner(),
            const SizedBox(height: 24),

            const Text(
              "LATEST LISTINGS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            _buildOpportunityItem(
              title: "World Bank Smallholder Grant",
              type: "GRANT",
              amount: "KSh 50,000",
              deadline: "2 Days Left",
            ),
            const SizedBox(height: 12),
            _buildOpportunityItem(
              title: "County Fertilizer Distribution",
              type: "TENDER",
              amount: "KSh 2.4M",
              deadline: "Feb 15",
            ),
            const SizedBox(height: 12),
            _buildOpportunityItem(
              title: "Youth in Ag Training",
              type: "TRAINING",
              amount: "FREE",
              deadline: "Open",
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF002E28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("NEW FUNDING", style: TextStyle(color: Color(0xFFC6FF00), fontWeight: FontWeight.bold, fontSize: 10)),
          SizedBox(height: 8),
          Text(
            "Dairy Modernization\nFund (2026)",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
          ),
          SizedBox(height: 12),
          Text("LPOs now accepted for hardware financing.", style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOpportunityItem({
    required String title,
    required String type,
    required String amount,
    required String deadline,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          // High-density "Odds-style" data block
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF2E7D32))),
                Text(deadline, style: const TextStyle(fontSize: 10, color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}