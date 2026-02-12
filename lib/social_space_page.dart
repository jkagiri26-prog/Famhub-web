import 'package:flutter/material.dart';

class SocialSpacePage extends StatefulWidget {
  const SocialSpacePage({super.key});

  @override
  State<SocialSpacePage> createState() => _SocialSpacePageState();
}

class _SocialSpacePageState extends State<SocialSpacePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Prevents page from rebuilding on tab switch

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final Color primaryGreen = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12), // FAMHUB spacing rule
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFeedCard(
                  author: "David Murimi",
                  role: "Coffee Farmer",
                  content: "Anyone seeing early rust in Kirinyaga? Looking for organic prevention tips.",
                  likes: "24",
                  comments: "8",
                  primary: primaryGreen,
                ),
                _buildFeedCard(
                  author: "Sarah Wanjiku",
                  role: "Organic Trader",
                  content: "Current market prices for Hass Avocados are peaking in Nairobi. Great time for harvest!",
                  likes: "56",
                  comments: "12",
                  primary: primaryGreen,
                ),
                const SizedBox(height: 80), // Padding for the floating bottom nav area
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard({
    required String author,
    required String role,
    required String content,
    required String likes,
    required String comments,
    required Color primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, 
                backgroundColor: primary.withOpacity(0.1),
                child: Icon(Icons.person, size: 18, color: primary)
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(author, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(role, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.thumb_up_off_alt, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(likes, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(comments, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}