/// ============================================================
/// FINANCING — MODULE LANDING (AGRI-FINANCE HUB)
/// ============================================================
///
/// Compact, mobile-first entry point of the Agri-Finance Hub.
///
/// Everything shown here is read from the real browse providers / products —
/// no hard-coded partners, offers, counts or financial figures. Category tiles
/// and search navigate into the existing catalogue screen (deep-linked via
/// `?tab=` / `?q=` / `?type=`) so filtering lives in exactly one place.
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

/// The four hub categories. These are the four `FinancingProductType` values
/// the hub surfaces; every tile deep-links into the catalogue's own product
/// filter, so no second filtering layer exists on this screen.
const List<FinancingProductType> _hubCategories = [
  FinancingProductType.loan,
  FinancingProductType.savings,
  FinancingProductType.insurance,
  FinancingProductType.inputFinancing,
];

/// GoRouter location for the catalogue with an optional query string.
String _catalogueLocation({String? tab, String? type, String? query}) {
  final params = <String, String>{};
  if (tab != null) params['tab'] = tab;
  if (type != null) params['type'] = type;
  if (query != null && query.isNotEmpty) params['q'] = query;
  final encoded = params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return encoded.isEmpty
      ? AppRoutes.financingCatalog
      : '${AppRoutes.financingCatalog}?$encoded';
}

class FinancingPage extends ConsumerStatefulWidget {
  const FinancingPage({super.key});

  @override
  ConsumerState<FinancingPage> createState() => _FinancingPageState();
}

class _FinancingPageState extends ConsumerState<FinancingPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  /// Live text used to narrow the featured preview below. It is applied to
  /// rows already returned by `financingBrowseProductsProvider` — the same
  /// approved catalogue data path the catalogue screen reads — so it adds no
  /// second data or filtering layer.
  String _hubQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    context.go(_catalogueLocation(tab: 'products', query: query));
  }

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

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinancingHubHeader(
            title: 'Agri-Finance Hub',
            subtitle: 'Loans • Savings • Insurance • Input financing',
            description: 'Explore funding, savings and protection products '
                'from verified financial partners. Everything listed is '
                'approved and published.',
          ),
          const SizedBox(height: 14),
          _HubSearchField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _hubQuery = value.trim()),
            onSubmit: _submitSearch,
          ),
          const SizedBox(height: 18),
          const SectionHeaderWidget(title: 'Explore by category'),
          const SizedBox(height: 10),
          const _CategoryGrid(categories: _hubCategories),
          const SizedBox(height: 20),
          SectionHeaderWidget(
            title: _hubQuery.isEmpty ? 'Featured offers' : 'Matching offers',
          ),
          const SizedBox(height: 10),
          _FeaturedOffers(query: _hubQuery),
          const SizedBox(height: 20),
          const SectionHeaderWidget(title: 'Verified partners'),
          const SizedBox(height: 10),
          const _ProvidersPreview(),
          const SizedBox(height: 20),
          const SectionHeaderWidget(title: 'Go to'),
          const SizedBox(height: 10),
          const _QuickLinks(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Search ─────────────────────────────────────────────────────────────────

/// Hub search. Typing narrows the featured preview in place; submitting opens
/// the catalogue pre-filtered with the same term.
class _HubSearchField extends StatelessWidget {
  const _HubSearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search loans, savings, insurance...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                iconSize: 18,
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.4),
        ),
      ),
    );
  }
}

// ── Categories ─────────────────────────────────────────────────────────────

/// 2×2 grid of the four hub categories. Each tile navigates to the catalogue
/// with that product type pre-selected, reusing the catalogue's own filter.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<FinancingProductType> categories;

  static const List<IconData> _icons = [
    Icons.account_balance_wallet_outlined,
    Icons.savings_outlined,
    Icons.health_and_safety_outlined,
    Icons.agriculture_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.05,
      children: [
        for (var i = 0; i < categories.length; i++)
          _CategoryTile(
            label: categories[i].label,
            icon: _icons[i % _icons.length],
            onTap: () => context.go(
              _catalogueLocation(tab: 'products', type: categories[i].dbValue),
            ),
          ),
      ],
    );
  }
}

/// Follows the established financing card convention (white card, 14 radius,
/// hairline border) used by the entry tiles on this feature.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data previews ──────────────────────────────────────────────────────────

/// Real published products, optionally narrowed by the hub search text.
class _FeaturedOffers extends ConsumerWidget {
  const _FeaturedOffers({required this.query});

  final String query;

  static bool _matches(FinancingProduct product, String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return product.name.toLowerCase().contains(needle) ||
        (product.summary?.toLowerCase().contains(needle) ?? false) ||
        (product.description?.toLowerCase().contains(needle) ?? false) ||
        product.productType.label.toLowerCase().contains(needle);
  }

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
        final matching =
            rows.where((p) => _matches(p, query)).toList(growable: false);

        if (matching.isEmpty) {
          return query.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No published products yet',
                  subtitle: 'Approved products appear here as soon as a '
                      'partner publishes them. Browse the catalogue to see '
                      'every provider.',
                )
              : EmptyStateWidget(
                  icon: Icons.search_off_outlined,
                  title: 'No matching products',
                  subtitle: 'Nothing published matches "$query" yet. Browse '
                      'the full catalogue or try another term.',
                  actionLabel: 'Browse catalogue',
                  onAction: () => context.go(
                    _catalogueLocation(tab: 'products', query: query),
                  ),
                );
        }

        final preview = matching.take(_landingPreviewCount).toList();
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
            _PreviewFooter(
              label: query.isEmpty
                  ? 'View all ${matching.length} products'
                  : 'See all results in catalogue',
              onOpen: () => context.go(
                _catalogueLocation(tab: 'products', query: query),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
          return const EmptyStateWidget(
            icon: Icons.storefront_outlined,
            title: 'No verified partners yet',
            subtitle: 'Partners appear here once they are verified and '
                'published. Browse the catalogue for the full workflow.',
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
            _PreviewFooter(
              label: 'View all ${rows.length} partners',
              onOpen: () =>
                  context.go(_catalogueLocation(tab: 'providers')),
            ),
          ],
        );
      },
    );
  }
}

// ── Quick links ────────────────────────────────────────────────────────────

/// Destinations out of the hub. "My Finance" has no registered route in this
/// build, so it is rendered as visibly unavailable rather than pointing at an
/// unrelated screen or inventing an account dashboard.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickLinkTile(
          title: 'Browse products',
          subtitle: 'Every approved and published product',
          icon: Icons.inventory_2_outlined,
          onTap: () => context.go(_catalogueLocation(tab: 'products')),
        ),
        const SizedBox(height: 10),
        _QuickLinkTile(
          title: 'Partners',
          subtitle: 'Verified banks, SACCOs and lenders',
          icon: Icons.storefront_outlined,
          onTap: () => context.go(_catalogueLocation(tab: 'providers')),
        ),
        const SizedBox(height: 10),
        const _UnavailableQuickLink(
          title: 'My Finance',
          subtitle: 'Accounts and balances are not available yet',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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

/// Placeholder for a destination that has no route yet. Not tappable, and it
/// does not navigate anywhere — it exists so the gap is visible rather than
/// silently omitted.
class _UnavailableQuickLink extends StatelessWidget {
  const _UnavailableQuickLink({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.grey.shade500;
    return Opacity(
      opacity: 0.72,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: muted,
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
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline, size: 18, color: muted),
          ],
        ),
      ),
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
