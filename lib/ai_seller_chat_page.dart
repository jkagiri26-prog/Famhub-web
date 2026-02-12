// Ensure this matches your file name: lib/pages/ai_seller_chat_page.dart
import 'package:flutter/material.dart';

class AiSellerChatPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isSellerView;

  const AiSellerChatPage({
    super.key, 
    required this.product, 
    this.isSellerView = false
  });

  @override
  State<AiSellerChatPage> createState() => _AiSellerChatPageState();
}

// ... rest of your code as provided ...