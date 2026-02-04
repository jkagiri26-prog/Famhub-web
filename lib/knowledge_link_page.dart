import 'package:flutter/material.dart';

/// FAMHUB Module: KnowledgeLinkPage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Standard: "Betpawa" high-density information architecture.
class KnowledgeLinkPage extends StatefulWidget {
  const KnowledgeLinkPage({super.key});

  @override
  State<KnowledgeLinkPage> createState() => _KnowledgeLinkPageState();
}

class _KnowledgeLinkPageState extends State<KnowledgeLinkPage> {
  final List<String> categories = ["Best Practices", "Pest Control", "Soil Health", "Markets"];
  String selectedCategory = "Best Practices";

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Knowledge Link',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Expert resources and agricultural guides.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Horizontal Category Switcher
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) => _buildCategoryChip(cat, primaryGreen)).toList(),
              ),
            ),
            const SizedBox(height: 24),

            _buildFeaturedArticle(context),
            const SizedBox(height: 24),

            const Text(
              "READING LIST",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            _buildArticleTile("Irrigation timing for Maize", "5 min read", Icons.water_drop),
            _buildArticleTile("Post-harvest storage tips", "8 min read", Icons.inventory_2),
            _buildArticleTile("Organic fertilizer mixing", "12 min read", Icons.eco),
            const SizedBox(height: 100), // Spacing for BottomNav
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, Color primary) {
    bool isSelected = selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => selectedCategory = label),
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? primary : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isSelected ? primary : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildFeaturedArticle(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              "https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600",
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FEATURED GUIDE",
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Maximizing Yield: The 2026 Potato Planting Protocol",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text("Read Article →", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildArticleTile(String title, String duration, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(duration, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}