import 'package:flutter/material.dart';

class LoanOfferCardWidget extends StatelessWidget {
  final String title;
  final String provider;
  final String amount;
  final String interest;
  final bool isPriority;

  const LoanOfferCardWidget({
    super.key,
    required this.title,
    required this.provider,
    required this.amount,
    required this.interest,
    required this.isPriority,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 110,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isPriority
                  ? const Color(0xFFF1F8E9)
                  : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPriority
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Column(
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  interest,
                  style: TextStyle(
                    fontSize: 10,
                    color: isPriority
                        ? Colors.green
                        : Colors.orange,
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