/// ============================================================
/// FINANCING — PRODUCT CARD
/// ============================================================
///
/// Renders one product of the catalogue.
///
/// Privacy: the public browse view carries no approval metadata, so
/// [FinancingProduct.approvalStatus] is null there and the approval /
/// publication chips are simply not rendered. Management screens show them
/// because those reads are permission-gated by RLS. Reviewer notes, actor ids
/// and metadata are never rendered anywhere.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';

import 'financing_status_chip_widget.dart';


class FinancingProductCardWidget extends StatelessWidget {
  const FinancingProductCardWidget({
    super.key,
    required this.product,
    this.providerName,
    this.showLifecycle = false,
    this.trailing,
    this.onTap,
  });

  final FinancingProduct product;

  /// Name of the owning provider (browse screens resolve it client-side).
  final String? providerName;

  /// When true (management screens), the approval / publication chips are
  /// rendered if the read actually carried them.
  final bool showLifecycle;

  final Widget? trailing;
  final VoidCallback? onTap;

  IconData get _typeIcon => switch (product.productType) {
        FinancingProductType.loan => Icons.account_balance_outlined,
        FinancingProductType.insurance => Icons.shield_outlined,
        FinancingProductType.savings => Icons.savings_outlined,
        FinancingProductType.assetFinancing => Icons.agriculture_outlined,
        FinancingProductType.inputFinancing => Icons.inventory_2_outlined,
        FinancingProductType.mobileMoney => Icons.phone_iphone_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final summary = product.summary;
    final amountRange = product.amountRangeLabel;
    final interest = product.interestLabel;
    final tenure = product.tenureLabel;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon, color: const Color(0xFF256D3A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (providerName != null && providerName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      providerName!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FinancingStatusChip(
                        label: product.productType.label,
                        tone: FinancingStatusTone.neutral,
                      ),
                      if (showLifecycle &&
                          product.approvalStatus != null) ...[
                        FinancingStatusChip(
                          label: product.approvalStatus!.label,
                          tone: approvalTone(product.approvalStatus!.dbValue),
                        ),
                        FinancingStatusChip(
                          label: product.isPublished ? 'Live' : 'Unpublished',
                          tone: product.isPublished
                              ? FinancingStatusTone.positive
                              : FinancingStatusTone.warning,
                          icon: product.isPublished
                              ? Icons.public
                              : Icons.visibility_off_outlined,
                        ),
                      ] else if (!showLifecycle) ...[
                        const FinancingStatusChip(
                          label: 'Live',
                          tone: FinancingStatusTone.positive,
                          icon: Icons.public,
                        ),
                      ],
                      if (amountRange != null)
                        FinancingStatusChip(
                          label: '${product.currency} $amountRange',
                          tone: FinancingStatusTone.info,
                          icon: Icons.payments_outlined,
                        ),
                    ],
                  ),
                  if (interest != null || tenure != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (interest != null) interest,
                        if (tenure != null) tenure,
                        if (product.requiresCollateral) 'Collateral required',
                      ].join('  •  '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (summary != null && summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
