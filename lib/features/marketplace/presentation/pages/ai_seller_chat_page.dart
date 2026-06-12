// Ensure this matches your file name: lib/pages/ai_seller_chat_page.dart
import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';

class AiSellerChatPage extends StatefulWidget {
  final Listing product;
  final bool isSellerView;

  const AiSellerChatPage({
    super.key, 
    required this.product, 
    this.isSellerView = false
  });

  @override
  State<AiSellerChatPage> createState() => _AiSellerChatPageState();
}

class _AiSellerChatPageState extends State<AiSellerChatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.title),
      ),
      body: Center(
        child: Text(
          'AI Seller Chat — ${widget.product.title}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
