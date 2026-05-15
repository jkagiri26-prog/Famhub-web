import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';

class SellerChatView extends StatelessWidget {
  const SellerChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),

          ModuleHeaderWidget(
            title: 'Seller Chat',
            subtitle: 'Negotiate ? Confirm ? Secure transaction',
          ),

          SizedBox(height: 24),

          Text(
            'Seller messaging interface placeholder',
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}