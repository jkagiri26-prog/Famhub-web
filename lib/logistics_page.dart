import 'package:flutter/material.dart';

/// FAMHUB Module: Logistics
/// Style: High-density fleet & shipment tracking.
class LogisticsPage extends StatelessWidget {
  const LogisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildActiveTracking(context, primary),
          const SizedBox(height: 24),
          const Text("AVAILABLE TRANSPORTERS", 
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildTruckCard(context, "Molo Express", "5 Ton Truck", "KSh 150/km", primary),
          _buildTruckCard(context, "Nakuru Logistics", "10 Ton Lorry", "KSh 280/km", primary),
          _buildTruckCard(context, "Farm-to-Market", "Pick-up 1 Ton", "KSh 80/km", primary),
          const SizedBox(height: 80), // Navigation clearance
        ],
      ),
    );
  }

  Widget _buildActiveTracking(BuildContext context, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              const Text("IN TRANSIT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const Spacer(),
              const Text("#SHP-9920", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          const Text("Maize - 50 Bags", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Text("Destination: Nairobi Millers", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.7,
            color: primary,
            backgroundColor: Colors.grey.shade100,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildTruckCard(BuildContext context, String name, String type, String rate, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Icon(Icons.local_shipping, color: primary, size: 24), // FIXED: Standard Material Icon
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Text(type, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rate, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)),
              const Text("per KM", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}