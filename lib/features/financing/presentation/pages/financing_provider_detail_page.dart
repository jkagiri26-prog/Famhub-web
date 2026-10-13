/// ============================================================
/// FINANCING — PROVIDER DETAIL
/// ============================================================
///
/// One verified provider and its approved, published products.
///
/// Addressed by the partner's public slug (`/finance/providers/:slug`) so the
/// screen survives a browser refresh and can be deep-linked directly. The
/// provider row is resolved from the browse catalogue; products are still
/// queried by `provider_id`, which is the foreign key — the slug only ever
/// addresses the page.
///
/// Only fields present on `financing.public_financial_providers` are rendered;
/// contact details, reviewer notes and metadata are not part of that view.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/router/route_names.dart';
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
  const FinancingProviderDetailPage({super.key, required this.slug});

  /// Canonical public identifier from
  /// `financing.public_financial_providers.slug`.
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const _DetailScaffold(
        child: LoadingStateWidget(message: 'Loading the provider...'),
      );
    }
    if (entityContext.isGuest) {
      return const _DetailScaffold(
        child: PermissionDeniedWidget(
          title: 'Provider locked',
          message: 'Sign in to view financing providers and products.',
        ),
      );
    }

    final providers = ref.watch(financingBrowseProvidersProvider);

    return providers.when(
      loading: () => const _DetailScaffold(
        child: LoadingStateWidget(message: 'Loading the provider...'),
      ),
      error: (error, _) => _DetailScaffold(
        child: ErrorStateWidget(
          title: error is FinancingCatalogueUnavailableException
              ? 'Catalogue not available'
              : 'Failed to load',
          message: error is FinancingCatalogueUnavailableException
              ? 'The financing catalogue is not available in this environment yet.'
              : 'We could not load this financing partner.',
          retryLabel:
              error is FinancingCatalogueUnavailableException ? null : 'Retry',
          onRetry: error is FinancingCatalogueUnavailableException
              ? null
              : () => ref.invalidate(financingBrowseProvidersProvider),
          detailedError: error is FinancingCatalogueUnavailableException
              ? null
              : error.toString(),
        ),
      ),
      data: (rows) {
        FinancingProvider? matched;
        for (final row in rows) {
          if (row.slug == slug) {
            matched = row;
            break;
          }
        }

        final provider = matched;
        if (provider == null) {
          // Deep links outlive catalogue edits: a partner can be unpublished,
          // suspended, or re-slugged at any time. Render a real state rather
          // than an empty shell or a crash.
          return const _DetailScaffold(
            child: EmptyStateWidget(
              icon: Icons.storefront_outlined,
              title: 'Provider not found',
              subtitle:
                  'This financing partner is not in the published catalogue. '
                  'It may have been unpublished, or the link may be out of date.',
            ),
          );
        }

        return _ProviderDetailBody(provider: provider);
      },
    );
  }
}

class _ProviderDetailBody extends ConsumerWidget {
  const _ProviderDetailBody({required this.provider});

  final FinancingProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(financingProviderProductsProvider(provider.id));
    final description = provider.description;

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackBar(),
          const SizedBox(height: 4),
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

/// Back affordance for this screen.
///
/// Follows the established sub-page convention (logistics shipment detail):
/// a left-aligned `TextButton.icon` reading "Back", which is reachable by
/// keyboard and read out as a single labelled control rather than an
/// unlabelled icon.
///
/// Behaviour differs from the imperative sub-pages it mirrors, because this
/// screen is now addressable by URL and so can be the first route on the
/// stack:
///   * reached by an in-app tap → `maybePop`, restoring the list and its
///     scroll position behind us;
///   * reached by a deep link or a browser refresh → nothing to pop, so fall
///     back to the Finance landing the detail page hangs off.
class _BackBar extends StatelessWidget {
  const _BackBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.maybePop();
          } else {
            context.go(AppRoutes.finance);
          }
        },
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back'),
      ),
    );
  }
}

/// Page chrome shared by every state of the provider detail screen.
///
/// The back affordance is deliberately part of the chrome rather than of the
/// loaded body: a partner that has been unpublished, a guest session, and a
/// catalogue outage all still need a way out.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackBar(),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
