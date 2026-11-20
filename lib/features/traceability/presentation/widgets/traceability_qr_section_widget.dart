import 'package:flutter/material.dart';

class TraceabilityQrSectionWidget extends StatelessWidget {
  const TraceabilityQrSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.network(
          'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=VUNIO_VERIFIED_9923',
          height: 150,
        ),

        const SizedBox(height: 8),

        const Text(
          'Scan to verify on VUNIO Ledger',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}