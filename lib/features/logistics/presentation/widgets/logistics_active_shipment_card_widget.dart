import 'package:flutter/material.dart';

class LogisticsActiveShipmentCardWidget extends StatelessWidget {
  const LogisticsActiveShipmentCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  color: primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                "IN TRANSIT",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Text(
                "#SHP-9920",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          const Text(
            "Maize - 50 Bags",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const Text(
            "Destination: Nairobi Millers",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

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
}