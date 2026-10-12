/// ============================================================
/// FINANCING — PROVIDER DETAIL
/// ============================================================
///
/// One verified provider and its approved, published products.
/// Pushed imperatively from the catalogue (established sub-page convention).
///
/// Only fields present on `financing.public_financial_providers` are rendered;
/// contact details, reviewer notes and metadata are not part of that view.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_product_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_status_chip_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';


class FinancingProviderDetailPage extends ConsumerWidget {
  const FinancingProviderDetailPage({super.key, required this.provider});

  final FinancingProvider provider;

  static Route<void> route({required FinancingProvider provider}) {
    return MaterialPageRoute<void>(
      builder: (_) => FinancingProviderDetailPage(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(financingProviderProductsProvider(provider.id));
    final description = provider.description;

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleHeaderWidget(
            title: provider.name,
            subtitle: partnerTypeLabel(provider.providerType),
            trailingIcon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FinancingStatusChip(
                      label: provider.verificationStatus.label,
                      tone: verificationTone(provider.verificationStatus.dbValue),
                      icon: Icons.verified_outlined,
                    ),
                    FinancingStatusChip(
                      label: partnerTypeLabel(provider.providerType),
                    ),
                    if (provider.countryCode != null &&
                        provider.countryCode!.isNotEmpty)
                      FinancingStatusChip(
                        label: provider.countryCode!.toUpperCase(),
                      ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description, style: const TextStyle(fontSize: 13)),
                ],
                if (provider.websiteUrl != null &&
                    provider.websiteUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.language, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          provider.websiteUrl!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeaderWidget(title: 'Available Products'),
          const SizedBox(height: 12),
          Expanded(
            child: products.when(
              loading: () => const LoadingStateWidget(
                message: 'Loading products...',
              ),
              error: (error, _) => ErrorStateWidget(
                title: error is FinancingCatalogueUnavailableException
                    ? 'Catalogue not available'
                    : 'Failed to Load',
                message: error is FinancingCatalogueUnavailableException
                    ? 'The financing catalogue is not available in this environment yet.'
                    : 'We could not load products for this provider.',
                retryLabel:
                    error is FinancingCatalogueUnavailableException ? null : 'Retry',
                onRetry: error is FinancingCatalogueUnavailableException
                    ? null
                    : () => ref.invalidate(
                          financingProviderProductsProvider(provider.id),
                        ),
                detailedError: error is FinancingCatalogueUnavailableException
                    ? null
                    : error.toString(),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No published products',
                    subtitle:
                        'This provider has no approved products available right now.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      FinancingProductCardWidget(product: rows[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
