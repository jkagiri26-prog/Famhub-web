import 'package:flutter/material.dart';

class PhoneInputWidget extends StatelessWidget {
  final TextEditingController controller;

  const PhoneInputWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+254 7XX XXX XXX',
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(
          Icons.phone_outlined,
        ),
      ),
    );
  }
}