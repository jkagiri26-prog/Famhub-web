import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';

import '../widgets/listing_card_widget.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic>? product;

  const ProductDetailPage({
    super.key,
    this.product,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          const ModuleHeaderWidget(
            title: 'Product Details',
            subtitle: 'Seller details ? AI insights ? Purchase flow',
          ),

          const SizedBox(height: 20),

          ListingCardWidget(
            title: product?['title'] ?? 'Fresh Hass Avocados',
            subtitle: product?['subtitle'] ?? 'Premium Grade ? Ready for Market',
            price: product?['price'] ?? 'KSh 3,500',
            location: product?['location'] ?? 'Nakuru',
          ),

          const SizedBox(height: 20),

          const Text(
            'AI Assistant + Seller Unlock System',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}