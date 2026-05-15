import 'package:flutter/material.dart';

class ListingFormWidget extends StatelessWidget {
  const ListingFormWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Product Title',
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Price',
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Location',
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Publish Listing'),
          ),
        ),
      ],
    );
  }
}