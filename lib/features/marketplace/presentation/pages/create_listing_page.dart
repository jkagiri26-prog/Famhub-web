import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../widgets/listing_form_widget.dart';

class CreateListingPage extends StatelessWidget {
  final Map<String, dynamic>? initialData;

  const CreateListingPage({super.key, this.initialData});

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          ModuleHeaderWidget(
            title: initialData != null ? 'Edit Listing' : 'Create Listing',
            subtitle: initialData != null
                ? 'Update your product, livestock or produce listing'
                : 'Add products, livestock or produce for sale',
          ),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: ListingFormWidget(initialData: initialData),
            ),
          ),
        ],
      ),
    );
  }
}