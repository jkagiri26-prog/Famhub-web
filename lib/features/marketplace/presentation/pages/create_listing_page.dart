import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../widgets/listing_form_widget.dart';

class CreateListingPage extends StatelessWidget {
  const CreateListingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveWrapperWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),

          ModuleHeaderWidget(
            title: 'Create Listing',
            subtitle: 'Add products, livestock or produce for sale',
          ),

          SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: ListingFormWidget(),
            ),
          ),
        ],
      ),
    );
  }
}