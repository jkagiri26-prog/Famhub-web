import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';

import '../widgets/publish_listing_form_widget.dart';

/// ============================================================
/// PUBLISH LISTING PAGE (MANAGED-STOCK, PHASE 1)
/// ============================================================
///
/// Reusable page that renders the [PublishListingFormWidget] for a
/// preselected managed-stock record.
///
/// Launch points:
///   - Marketplace → Add Listing → StockSelectionPage → this page
///   - Farm / Shop / Livestock stock screens with the relevant
///     stock_id preselected.
/// ============================================================
class PublishListingPage extends StatelessWidget {
  /// The selected managed-stock record id (commerce.stock_registry.id).
  final String stockId;

  /// Optional pre-filled title for the listing.
  final String? initialTitle;

  const PublishListingPage({
    super.key,
    required this.stockId,
    this.initialTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          const ModuleHeaderWidget(
            title: 'Publish Listing',
            subtitle: 'Sell from your managed stock',
          ),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: PublishListingFormWidget(
                stockId: stockId,
                initialTitle: initialTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
