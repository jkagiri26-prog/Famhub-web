import 'package:flutter/material.dart';

class ReferralWithdrawButtonWidget extends StatelessWidget {
  const ReferralWithdrawButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        child: const Text(
          'Withdraw to M-Pesa',
        ),
      ),
    );
  }
}