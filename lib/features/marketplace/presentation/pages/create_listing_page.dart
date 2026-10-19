import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../widgets/create_listing_form_widget.dart';

/// ============================================================
/// CREATE LISTING PAGE (STANDALONE — NO MANAGED STOCK REQUIRED)
/// ============================================================
///
/// Shared farmer-side listing entry point. Accepts optional farm crop/asset
/// context (product variant, location, title, context label) so the same
/// form serves both:
///   - "Sell on Marketplace" from a specific crop/livestock/asset, and
///   - a general listing from the active farm workspace.
///
/// No stock record is required: `stock_id` stays null.
/// ============================================================
class CreateListingPage extends StatelessWidget {
  final String? initialVariantId;
  final String? initialTitle;
  final String? initialContextLabel;
  final String? initialLocationId;
  final String? initialLocationName;

  const CreateListingPage({
    super.key,
    this.initialVariantId,
    this.initialTitle,
    this.initialContextLabel,
    this.initialLocationId,
    this.initialLocationName,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const ModuleHeaderWidget(
            title: 'Sell on Marketplace',
            subtitle: 'List what you have for sale',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: CreateListingFormWidget(
                initialVariantId: initialVariantId,
                initialTitle: initialTitle,
                initialContextLabel: initialContextLabel,
                initialLocationId: initialLocationId,
                initialLocationName: initialLocationName,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
