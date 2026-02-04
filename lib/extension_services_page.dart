import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// FAMHUB Module: ExtensionServicesPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
class ExtensionServicesPage extends StatefulWidget {
  const ExtensionServicesPage({super.key});

  @override
  State<ExtensionServicesPage> createState() => _ExtensionServicesPageState();
}

class _ExtensionServicesPageState extends State<ExtensionServicesPage> {
  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      // "Betpawa" spacing rule: 16.0 horizontal, minimal top padding
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extension Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Expert advice and field support at your fingertips.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            _buildExpertCard(
              name: "Dr. Jane Kamau",
              specialty: "Soil Science & Fertility",
              status: "Online",
              imageUrl: "https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=200",
            ),
            const SizedBox(height: 12),
            _buildExpertCard(
              name: "Officer Samuel Otieno",
              specialty: "Livestock Management",
              status: "In Field",
              imageUrl: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200",
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExpertCard({
    required String name, 
    required String specialty, 
    required String status,
    required String imageUrl
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade100),
              errorWidget: (context, url, error) => const Icon(Icons.account_circle, size: 60),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(specialty, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: status == "Online" ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                )
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.chat_outlined, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}