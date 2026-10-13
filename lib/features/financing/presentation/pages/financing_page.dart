/// ============================================================
/// FINANCING — MODULE LANDING
/// ============================================================
///
/// Entry point of the Agri-Finance Hub. Everything below the two catalogue
/// entry tiles is read from the real browse providers / products — this page
/// used to ship hard-coded partners, loan offers and a fabricated credit
/// score, none of which came from a data source.
///
/// Architecture Compliance:
/// - No Scaffold / AppBar / Drawer / BottomNavigationBar (shell owns them)
/// - ResponsiveWrapper enforced
/// - Loading / empty / error / guest states are always rendered
/// - Reads only the public browse providers; no permission required beyond
///   an authenticated session
/// - All navigation goes through GoRouter (`context.go` for the catalogue
///   screens, `context.push` for the provider drill-down) so the URL, the
///   browser back/forward buttons and the shell selection stay in sync
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
import 'package:famhub_app/features/financing/presentation/widgets/financing_provider_card_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_hub_widgets.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

/// How many rows each landing section previews; the full list lives on the
/// catalogue screen.
const int _landingPreviewCount = 3;

class FinancingPage extends ConsumerStatefulWidget {
  const FinancingPage({super.key});

  @override
  ConsumerState<FinancingPage> createState() => _FinancingPageState();
}

class _FinancingPageState extends ConsumerState<FinancingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Loading the finance hub...'),
      );
    }
    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Finance hub locked',
          message: 'Sign in to browse financing providers and products.',
        ),
      );
    }

    return const ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinancingHubHeader(
            title: 'Agri-Finance Hub',
            subtitle: 'Loans • Savings • Insurance • Input financing',
            description: 'Everything offered by verified financial partners '
                'in the FAMHUB catalogue. Products shown here have passed '
                'review and are published.',
          ),
          SizedBox(height: 16),
          _CatalogueEntryCard(
            title: 'Browse catalogue',
            subtitle: 'Verified partners and their published products',
            icon: Icons.storefront_outlined,
            location: AppRoutes.financingCatalog,
          ),
          SizedBox(height: 10),
          _CatalogueEntryCard(
            title: 'Manage catalogue',
            subtitle: 'Providers, verification and product lifecycle',
            icon: Icons.manage_accounts_outlined,
            location: AppRoutes.financingManagement,
          ),
          SizedBox(height: 26),
          SectionHeaderWidget(title: 'Verified partners'),
          SizedBox(height: 12),
          _ProvidersPreview(),
          SizedBox(height: 24),
          SectionHeaderWidget(title: 'Published products'),
          SizedBox(height: 12),
          _ProductsPreview(),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Data previews ──────────────────────────────────────────────────────────

class _ProvidersPreview extends ConsumerWidget {
  const _ProvidersPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(financingBrowseProvidersProvider);

    return providers.when(
      loading: () => const _PreviewSkeleton(),
      error: (error, _) => _PreviewError(
        message: error is FinancingCatalogueUnavailableException
            ? 'The financing catalogue is not available in this environment yet.'
            : 'We could not load the verified partners.',
        onRetry: error is FinancingCatalogueUnavailableException
            ? null
            : () => ref.invalidate(financingBrowseProvidersProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.storefront_outlined,
            title: 'No verified partners yet',
            subtitle:
                'Partners appear here once they are verified and published. '
                'Browse the catalogue for the full workflow.',
            actionLabel: 'Browse catalogue',
            onAction: () => context.go(AppRoutes.financingCatalog),
          );
        }
        final preview = rows.take(_landingPreviewCount).toList(growable: false);
        return Column(
          children: [
            for (final provider in preview) ...[
              FinancingProviderCardWidget(
                provider: provider,
                onTap: () => context.push(
                  AppRoutes.financingProviderLocation(provider.slug),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (rows.length > preview.length)
              _PreviewFooter(
                label: 'View all ${rows.length} partners',
                onOpen: () => context.go(AppRoutes.financingCatalog),
              ),
          ],
        );
      },
    );
  }
}

class _ProductsPreview extends ConsumerWidget {
  const _ProductsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(financingBrowseProductsProvider);
    final providers = ref.watch(financingBrowseProvidersProvider);
    final names = <String, String>{
      for (final p in providers.value ?? const <FinancingProvider>[])
        p.id: p.name,
    };

    return products.when(
      loading: () => const _PreviewSkeleton(),
      error: (error, _) => _PreviewError(
        message: error is FinancingCatalogueUnavailableException
            ? 'The financing catalogue is not available in this environment yet.'
            : 'We could not load the published products.',
        onRetry: error is FinancingCatalogueUnavailableException
            ? null
            : () => ref.invalidate(financingBrowseProductsProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No published products yet',
            subtitle:
                'Approved products appear here as soon as a partner publishes '
                'them. Browse the catalogue to see every provider.',
            actionLabel: 'Browse catalogue',
            onAction: () => context.go(AppRoutes.financingCatalog),
          );
        }
        final preview = rows.take(_landingPreviewCount).toList(growable: false);
        return Column(
          children: [
            for (final product in preview) ...[
              FinancingProductCardWidget(
                product: product,
                providerName: names[product.providerId],
                onTap: () {
                  final providerId = product.providerId;
                  final provider = providers.value?.where(
                    (p) => p.id == providerId,
                  );
                  if (provider == null || provider.isEmpty) return;
                  context.push(
                    AppRoutes.financingProviderLocation(provider.first.slug),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            if (rows.length > preview.length)
              _PreviewFooter(
                label: 'View all ${rows.length} products',
                onOpen: () => context.go(AppRoutes.financingCatalog),
              ),
          ],
        );
      },
    );
  }
}

// ── Preview helpers ────────────────────────────────────────────────────────

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LoadingStateWidget(message: 'Loading the catalogue...');
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      title: 'Not available',
      message: message,
      retryLabel: onRetry == null ? null : 'Retry',
      onRetry: onRetry,
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  const _PreviewFooter({required this.label, required this.onOpen});

  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onOpen,
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1B5E20),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

// ── Entry tiles ────────────────────────────────────────────────────────────

/// Entry tile for one of the catalogue screens. Follows the established
/// financing card convention (white card, 14 radius, hairline border).
///
/// Navigates with `context.go` so the URL, the browser back/forward buttons
/// and the shell selection stay in sync with the screen on show.
class _CatalogueEntryCard extends StatelessWidget {
  const _CatalogueEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.location,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// GoRouter location, from `AppRoutes`.
  final String location;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(location),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
