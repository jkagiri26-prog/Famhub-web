/// ============================================================
/// FINANCING — PUBLIC CATALOGUE
/// ============================================================
///
/// Browse verified providers and their approved, published products.
///
/// Architecture Compliance:
/// - No Scaffold / AppBar / Drawer / BottomNavigationBar (shell owns them)
/// - ResponsiveWrapper enforced
/// - Loading / empty / error / permission states are always rendered
/// - Reads only `financing.public_financial_*` views — no permission needed
///   beyond an authenticated session, and no private column is reachable
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_provider_detail_page.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_product_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_provider_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_status_chip_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_hub_widgets.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';


class FinancingCataloguePage extends ConsumerStatefulWidget {
  const FinancingCataloguePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const FinancingCataloguePage());
  }

  @override
  ConsumerState<FinancingCataloguePage> createState() =>
      _FinancingCataloguePageState();
}

class _FinancingCataloguePageState extends ConsumerState<FinancingCataloguePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  FinancialPartnerType? _partnerFilter;
  FinancingProductType? _productFilter;

  static const List<FinancialPartnerType> _partnerFilters = [
    FinancialPartnerType.bank,
    FinancialPartnerType.sacco,
    FinancialPartnerType.insurance,
    FinancialPartnerType.microfinance,
    FinancialPartnerType.lendingPlatform,
    FinancialPartnerType.mobileMoney,
  ];

  static const List<FinancingProductType> _productFilters = [
    FinancingProductType.loan,
    FinancingProductType.insurance,
    FinancingProductType.savings,
    FinancingProductType.assetFinancing,
    FinancingProductType.inputFinancing,
    FinancingProductType.mobileMoney,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      final value = _searchController.text.trim();
      if (value != _query) setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(String haystack) =>
      _query.isEmpty || haystack.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final entityContext = ref.watch(contextProvider);

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Loading the catalogue...'),
      );
    }
    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Catalogue locked',
          message: 'Sign in to browse financing providers and products.',
        ),
      );
    }

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinancingHubHeader(
            title: 'Provider Catalogue',
            subtitle: 'Verified partners • Approved products',
            description: 'Only verified providers and their approved, '
                'published products are listed here. Search by name or pick '
                'a partner type to narrow the list.',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 14),
          FinancingSegmentedTabs(
            controller: _tabController,
            tabs: const [
              FinancingTabSpec(
                icon: Icons.storefront_outlined,
                label: 'Providers',
              ),
              FinancingTabSpec(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search providers and products',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      iconSize: 18,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
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
                borderSide:
                    const BorderSide(color: Color(0xFF2E7D32), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProvidersTab(),
                _buildProductsTab(),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Providers ───────────────────────────────────────────────────────────

  Widget _buildProvidersTab() {
    final providers = ref.watch(financingBrowseProvidersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(
                label: 'All',
                selected: _partnerFilter == null,
                onSelected: (_) => setState(() => _partnerFilter = null),
              ),
              for (final type in _partnerFilters)
                _filterChip(
                  label: partnerTypeLabel(type),
                  selected: _partnerFilter == type,
                  onSelected: (_) => setState(
                    () => _partnerFilter = _partnerFilter == type ? null : type,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: providers.when(
            loading: () => const LoadingStateWidget(
              message: 'Loading providers...',
            ),
            error: (error, _) => _CatalogueErrorState(
              error: error,
              onRetry: () => ref.invalidate(financingBrowseProvidersProvider),
            ),
            data: (rows) {
              final filtered = rows
                  .where((p) =>
                      (_partnerFilter == null || p.providerType == _partnerFilter) &&
                      _matchesQuery('${p.name} ${p.description ?? ''}'))
                  .toList(growable: false);

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.storefront_outlined,
                  title: rows.isEmpty ? 'No providers yet' : 'No matches',
                  subtitle: rows.isEmpty
                      ? 'Verified financing partners will appear here once they are published.'
                      : 'Try a different search or filter.',
                  actionLabel: rows.isEmpty || _query.isEmpty ? null : 'Clear',
                  onAction: rows.isEmpty || _query.isEmpty
                      ? null
                      : () => _searchController.clear(),
                );
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final provider = filtered[index];
                  return FinancingProviderCardWidget(
                    provider: provider,
                    onTap: () => Navigator.of(context).push(
                      FinancingProviderDetailPage.route(provider: provider),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Products ────────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    final products = ref.watch(financingBrowseProductsProvider);
    final providers = ref.watch(financingBrowseProvidersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(
                label: 'All',
                selected: _productFilter == null,
                onSelected: (_) => setState(() => _productFilter = null),
              ),
              for (final type in _productFilters)
                _filterChip(
                  label: type.label,
                  selected: _productFilter == type,
                  onSelected: (_) => setState(
                    () => _productFilter = _productFilter == type ? null : type,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: products.when(
            loading: () => const LoadingStateWidget(
              message: 'Loading products...',
            ),
            error: (error, _) => _CatalogueErrorState(
              error: error,
              onRetry: () => ref.invalidate(financingBrowseProductsProvider),
            ),
            data: (rows) {
              final names = <String, String>{
                for (final p in providers.value ?? const <FinancingProvider>[])
                  p.id: p.name,
              };
              final filtered = rows
                  .where((p) =>
                      (_productFilter == null || p.productType == _productFilter) &&
                      _matchesQuery(
                          '${p.name} ${p.summary ?? ''} ${names[p.providerId] ?? ''}'))
                  .toList(growable: false);

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: rows.isEmpty ? 'No products yet' : 'No matches',
                  subtitle: rows.isEmpty
                      ? 'Approved and published financing products will appear here.'
                      : 'Try a different search or filter.',
                  actionLabel: rows.isEmpty || _query.isEmpty ? null : 'Clear',
                  onAction: rows.isEmpty || _query.isEmpty
                      ? null
                      : () => _searchController.clear(),
                );
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  return FinancingProductCardWidget(
                    product: product,
                    providerName: names[product.providerId],
                    onTap: product.providerId.isEmpty
                        ? null
                        : () {
                            final provider = (providers.value ??
                                    const <FinancingProvider>[])
                                .where((p) => p.id == product.providerId);
                            if (provider.isNotEmpty) {
                              Navigator.of(context).push(
                                FinancingProviderDetailPage.route(
                                  provider: provider.first,
                                ),
                              );
                            }
                          },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      ),
    );
  }
}

/// Shared error surface for the catalogue. Distinguishes "not deployed yet"
/// from a transient failure so the message is never misleading.
class _CatalogueErrorState extends StatelessWidget {
  const _CatalogueErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notDeployed = error is FinancingCatalogueUnavailableException;
    return ErrorStateWidget(
      title: notDeployed ? 'Catalogue not available' : 'Failed to Load',
      message: notDeployed
          ? 'The financing catalogue is not available in this environment yet.'
          : 'We could not load the financing catalogue.',
      retryLabel: notDeployed ? null : 'Retry',
      onRetry: notDeployed ? null : onRetry,
      detailedError: notDeployed ? null : error.toString(),
    );
  }
}
