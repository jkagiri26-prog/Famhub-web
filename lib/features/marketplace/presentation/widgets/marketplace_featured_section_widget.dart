import 'package:flutter/material.dart';

class MarketplaceFeaturedSectionWidget extends StatelessWidget {
  const MarketplaceFeaturedSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Text(
        'Featured AI + Listings Area',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}