// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// FAMHUB Module: MarketplacePage
/// Protocol: Root width: double.infinity, No Scaffold.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          Text(
            'MARKETPLACE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildMarketCard("Premium Hybrid Maize", "KSh 4,500", "90kg Bag", primaryGreen),
          _buildMarketCard("Organic Fertilizer", "KSh 2,800", "50kg Bag", primaryGreen),
          _buildMarketCard("Drip Irrigation Kit", "KSh 12,000", "Per Acre", primaryGreen),
          const SizedBox(height: 100), // Navigation clearance
        ],
      ),
    );
  }

  Widget _buildMarketCard(String title, String price, String unit, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1), // Standard fallback
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag_outlined, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(price, style: TextStyle(fontWeight: FontWeight.w900, color: primary)),
        ],
      ),
    );
  }
}