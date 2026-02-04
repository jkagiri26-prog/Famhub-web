import 'package:flutter/material.dart';

/// FAMHUB Module: FinancingPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Styling: High-contrast credit metrics and "Odds-style" financial buttons.
class FinancingPage extends StatefulWidget {
  const FinancingPage({super.key});

  @override
  State<FinancingPage> createState() => _FinancingPageState();
}

class _FinancingPageState extends State<FinancingPage> {
  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      // "Betpawa" spacing rule: 16.0 horizontal padding
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agri-Finance Hub',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage credit, insurance, and input loans.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Credit Score Component
            _buildCreditHealthCard(),
            const SizedBox(height: 24),

            const Text(
              "ACTIVE LOAN OFFERS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),

            _buildLoanOffer(
              title: "Pre-Season Input Loan",
              provider: "Apollo Agri",
              amount: "KSh 25,000",
              interest: "5% Monthly",
            ),
            const SizedBox(height: 12),
            _buildLoanOffer(
              title: "Emergency Harvest Credit",
              provider: "FamHub Finance",
              amount: "KSh 5,000",
              interest: "Instant",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditHealthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // High contrast dark for finance
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Your Credit Score", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("BULLISH", style: TextStyle(color: Colors.greenAccent.shade400, fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              const Text("745 / 900", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.78,
              minHeight: 8,
              backgroundColor: Colors.white10,
              color: Colors.greenAccent.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanOffer({
    required String title,
    required String provider,
    required String amount,
    required String interest,
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(provider, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          // Odds-style Purchase Button
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
                Text(interest, style: const TextStyle(fontSize: 10, color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}