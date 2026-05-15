import 'package:flutter/material.dart';

class OtpInputWidget extends StatelessWidget {
  final TextEditingController controller;

  const OtpInputWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.number,
      decoration: InputDecoration(
        labelText: 'OTP Code',
        hintText: 'Enter verification code',
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
        ),
      ),
    );
  }
}