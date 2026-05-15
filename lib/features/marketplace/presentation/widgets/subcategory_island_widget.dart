mport 'package:flutter/material.dart';

import 'listing_card_widget.dart';

class SubcategoryIslandWidget extends StatelessWidget {
  final String title;

  const SubcategoryIslandWidget({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 12),

        const ListingCardWidget(
          title: 'Sample Listing',
          subtitle: 'High quality produce available',
          price: 'KSh 2,500',
          location: 'Eldoret',
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}