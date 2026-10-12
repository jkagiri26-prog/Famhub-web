/// ============================================================
/// FINANCING — PROVIDER CARD
/// ============================================================
///
/// Renders one row of the provider catalogue. Follows the established
/// financing card convention (white card, 14 radius, grey hairline border).
///
/// Never renders contact details, reviewer notes or metadata — the public
/// browse surface does not carry them and the management screens deliberately
/// do not show them either.
/// ============================================================
library;

import 'package:flutter/material.dart';

import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';

import 'financing_status_chip_widget.dart';


class FinancingProviderCardWidget extends StatelessWidget {
  const FinancingProviderCardWidget({
    super.key,
    required this.provider,
    this.productCount,
    this.trailing,
    this.onTap,
  });

  final FinancingProvider provider;

  /// Optional count shown under the description (browse screens only).
  final int? productCount;

  /// Rendered on the right — used by management screens for quick actions.
  final Widget? trailing;

  final VoidCallback? onTap;

  IconData get _typeIcon => switch (provider.providerType) {
        FinancialPartnerType.bank => Icons.account_balance_outlined,
        FinancialPartnerType.sacco => Icons.groups_outlined,
        FinancialPartnerType.insurance => Icons.shield_outlined,
        FinancialPartnerType.microfinance => Icons.trending_up_outlined,
        FinancialPartnerType.lendingPlatform => Icons.handshake_outlined,
        FinancialPartnerType.mobileMoney => Icons.phone_iphone_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final description = provider.description;

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
              child: provider.logoUrl != null && provider.logoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        provider.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(_typeIcon, color: const Color(0xFF256D3A)),
                      ),
                    )
                  : Icon(_typeIcon, color: const Color(0xFF256D3A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      FinancingStatusChip(
                        label: provider.verificationStatus.label,
                        tone: verificationTone(provider.verificationStatus.dbValue),
                        icon: provider.verificationStatus ==
                                FinancingVerificationStatus.verified
                            ? Icons.verified_outlined
                            : Icons.hourglass_top_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FinancingStatusChip(
                        label: partnerTypeLabel(provider.providerType),
                        tone: FinancingStatusTone.neutral,
                      ),
                      if (provider.countryCode != null &&
                          provider.countryCode!.isNotEmpty)
                        FinancingStatusChip(
                          label: provider.countryCode!.toUpperCase(),
                          tone: FinancingStatusTone.neutral,
                        ),
                      if (productCount != null)
                        FinancingStatusChip(
                          label: productCount == 1
                              ? '1 product'
                              : '$productCount products',
                          tone: FinancingStatusTone.info,
                        ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
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
            ] else if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
