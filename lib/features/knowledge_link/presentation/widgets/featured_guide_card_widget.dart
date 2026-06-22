import 'package:flutter/material.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class FeaturedGuideCardWidget extends StatelessWidget {
  const FeaturedGuideCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SectionContainerWidget(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Image.network(
              "https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600",
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 160,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FEATURED GUIDE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Maximizing Yield: The 2026 Potato Planting Protocol",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {},
                  child: Text(
                    "Read Article →",
                    style: TextStyle(color: primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}