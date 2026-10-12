/// ============================================================
/// FINANCING — CATALOGUE MANAGEMENT
/// ============================================================
///
/// Provider and product administration for authorized users.
///
/// Architecture Compliance:
/// - No Scaffold / AppBar / Drawer (shell owns them)
/// - ResponsiveWrapper enforced
/// - Gated on the backend `finance.*` keys — nothing is granted client side.
///   Grants live in `role_permissions` + `entity_role_scopes` for the active
///   entity, so a profile without them renders the locked state below rather
///   than data.
/// - Writes are RPC-only; no direct table access exists in the contract.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_management_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_permission_provider.dart';
import 'package:famhub_app/features/financing/config/permissions.dart';
import 'package:famhub_app/features/financing/domain/financing_slug.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_hub_widgets.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_product_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_provider_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_status_chip_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';


class FinancingManagementPage extends ConsumerStatefulWidget {
  const FinancingManagementPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const FinancingManagementPage(),
    );
  }

  @override
  ConsumerState<FinancingManagementPage> createState() =>
      _FinancingManagementPageState();
}

class _FinancingManagementPageState
    extends ConsumerState<FinancingManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Provider-tab search + verification filter (client side; the managed
  /// fetch already returns the full set for the active entity).
  final TextEditingController _providerSearchController =
      TextEditingController();
  String _providerQuery = '';
  FinancingVerificationStatus? _verificationFilter;

  /// Product-tab search + approval filter, same rules as the provider tab.
  final TextEditingController _productSearchController =
      TextEditingController();
  String _productQuery = '';
  FinancingApprovalStatus? _approvalFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _providerSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  bool _can(String permission) =>
      ref.read(financingPermissionStatusProvider(permission)).isAllowed;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeFinancingActionError(error))),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final entityContext = ref.watch(contextProvider);
    final access =
        ref.watch(financingAnyPermissionStatusProvider(FinancingPermissions.all));

    if (entityContext.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Checking catalogue access...'),
      );
    }
    if (entityContext.isGuest) {
      return const ResponsiveWrapper(
        child: PermissionDeniedWidget(
          title: 'Catalogue management locked',
          message: 'Sign in to manage financing providers and products.',
        ),
      );
    }
    if (access.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Checking catalogue access...'),
      );
    }
    if (!access.isAllowed) {
      return ResponsiveWrapper(
        child: access.isUnavailable
            ? const PermissionDeniedWidget(
                title: 'Catalogue unavailable',
                message: 'Permissions are not available right now.',
              )
            : PermissionDeniedWidget(
                title: 'Catalogue management locked',
                message: access.reason ??
                    'Catalogue management is not enabled for your role.',
              ),
      );
    }

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinancingHubHeader(
            title: 'Catalogue Management',
            subtitle: 'Providers • Verification • Product lifecycle',
            description: 'Add providers, verify partners, and move products '
                'through review and publication. Every action runs against '
                'your active entity context and its finance permissions.',
            icon: Icons.manage_accounts_outlined,
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
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildProvidersTab(), _buildProductsTab()],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Providers tab ───────────────────────────────────────────────────────

  Widget _buildProvidersTab() {
    final providers = ref.watch(financingManagedProvidersProvider);
    final canManage = _can(FinancingPermissions.manageProviders);
    final canVerify = _can(FinancingPermissions.verifyProviders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _addAction(
          onPressed: canManage ? () => _showProviderForm() : null,
          label: 'Add provider',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _providerSearchController,
          onChanged: (value) => setState(() => _providerQuery = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name, slug or description',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _providerQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    iconSize: 18,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _providerSearchController.clear();
                      setState(() => _providerQuery = '');
                    },
                  ),
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
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChip(
                label: 'All',
                selected: _verificationFilter == null,
                onSelected: (_) => setState(() => _verificationFilter = null),
              ),
              for (final status in FinancingVerificationStatus.values)
                _filterChip(
                  label: status.label,
                  selected: _verificationFilter == status,
                  onSelected: (_) => setState(
                    () => _verificationFilter =
                        _verificationFilter == status ? null : status,
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
            error: (error, _) => ErrorStateWidget(
              title: error is FinancingCatalogueUnavailableException
                  ? 'Catalogue not available'
                  : 'Failed to Load',
              message: error is FinancingCatalogueUnavailableException
                  ? 'The financing catalogue is not available in this environment yet.'
                  : 'We could not load the provider catalogue.',
              retryLabel: error is FinancingCatalogueUnavailableException
                  ? null
                  : 'Retry',
              onRetry: error is FinancingCatalogueUnavailableException
                  ? null
                  : () => ref.invalidate(financingManagedProvidersProvider),
              detailedError: error is FinancingCatalogueUnavailableException
                  ? null
                  : error.toString(),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.storefront_outlined,
                  title: 'No providers yet',
                  subtitle: canManage
                      ? 'Add the first financing partner to start the verification workflow.'
                      : 'No providers are visible to your role.',
                  actionLabel: canManage ? 'Add provider' : null,
                  onAction: canManage ? () => _showProviderForm() : null,
                );
              }
              final query = _providerQuery.trim().toLowerCase();
              final filtered = rows
                  .where((p) =>
                      (_verificationFilter == null ||
                          p.verificationStatus == _verificationFilter) &&
                      (query.isEmpty ||
                          '${p.name} ${p.slug} ${p.description ?? ''}'
                              .toLowerCase()
                              .contains(query)))
                  .toList(growable: false);

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.search_off_outlined,
                  title: 'No matching providers',
                  subtitle:
                      'No provider matches "${_providerQuery.trim()}". Clear '
                      'the search or pick a different verification filter.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _providerSearchController.clear();
                    setState(() {
                      _providerQuery = '';
                      _verificationFilter = null;
                    });
                  },
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
                    trailing: (canManage || canVerify)
                        ? PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (action) =>
                                _handleProviderAction(action, provider),
                            itemBuilder: (_) => [
                              if (canManage)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                              if (canVerify &&
                                  provider.verificationStatus !=
                                      FinancingVerificationStatus.verified)
                                const PopupMenuItem(
                                  value: 'verify',
                                  child: Text('Mark verified'),
                                ),
                              if (canVerify &&
                                  provider.verificationStatus !=
                                      FinancingVerificationStatus.rejected)
                                const PopupMenuItem(
                                  value: 'reject',
                                  child: Text('Reject'),
                                ),
                              if (canVerify &&
                                  provider.verificationStatus !=
                                      FinancingVerificationStatus.suspended)
                                const PopupMenuItem(
                                  value: 'suspend',
                                  child: Text('Suspend'),
                                ),
                            ],
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Primary call to action for a tab: full width on narrow phones, right
  /// aligned where there is room for it.
  Widget _addAction({required VoidCallback? onPressed, required String label}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final button = FinancingPrimaryButton(
          onPressed: onPressed,
          label: label,
        );
        if (constraints.maxWidth < 520) {
          return SizedBox(width: double.infinity, child: button);
        }
        return Align(alignment: Alignment.centerRight, child: button);
      },
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
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? const Color(0xFF1B5E20) : Colors.grey.shade700,
        ),
        side: BorderSide(
          color: selected
              ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
              : Colors.grey.shade300,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _handleProviderAction(
    String action,
    FinancingProvider provider,
  ) async {
    if (action == 'edit') {
      await _showProviderForm(existing: provider);
      return;
    }
    final status = switch (action) {
      'verify' => FinancingVerificationStatus.verified,
      'reject' => FinancingVerificationStatus.rejected,
      'suspend' => FinancingVerificationStatus.suspended,
      _ => null,
    };
    if (status == null) return;

    final confirmed = await _confirm(
      title: 'Mark "${provider.name}" as ${status.label}?',
      message: status == FinancingVerificationStatus.verified
          ? 'The provider becomes eligible for public listing.'
          : 'Rejecting or suspending resets every product of this provider '
              'back to draft and unpublishes it.',
      confirmLabel: status.label,
      destructive: status != FinancingVerificationStatus.verified,
    );
    if (confirmed != true) return;

    await _run(() async {
      await ref.read(financingCatalogueActionsProvider).verifyProvider(
            providerId: provider.id,
            status: status,
          );
      _showMessage('"${provider.name}" is now ${status.label.toLowerCase()}.');
    });
  }

  // ── Products tab ────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    final products = ref.watch(financingManagedProductsProvider);
    final providers = ref.watch(financingManagedProvidersProvider);
    final canManage = _can(FinancingPermissions.manageProducts);
    final canReview = _can(FinancingPermissions.reviewProducts);
    final canPublish = _can(FinancingPermissions.publishProducts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _addAction(
          onPressed: canManage
              ? () => _showProductForm(
                    providerOptions: providers.value ?? const [],
                  )
              : null,
          label: 'Add product',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _productSearchController,
          onChanged: (value) => setState(() => _productQuery = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by product name, slug or provider',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _productQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    iconSize: 18,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _productSearchController.clear();
                      setState(() => _productQuery = '');
                    },
                  ),
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
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChip(
                label: 'All',
                selected: _approvalFilter == null,
                onSelected: (_) => setState(() => _approvalFilter = null),
              ),
              for (final status in FinancingApprovalStatus.values)
                _filterChip(
                  label: status.label,
                  selected: _approvalFilter == status,
                  onSelected: (_) => setState(
                    () => _approvalFilter =
                        _approvalFilter == status ? null : status,
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
            error: (error, _) => ErrorStateWidget(
              title: error is FinancingCatalogueUnavailableException
                  ? 'Catalogue not available'
                  : 'Failed to Load',
              message: error is FinancingCatalogueUnavailableException
                  ? 'The financing catalogue is not available in this environment yet.'
                  : 'We could not load the product catalogue.',
              retryLabel: error is FinancingCatalogueUnavailableException
                  ? null
                  : 'Retry',
              onRetry: error is FinancingCatalogueUnavailableException
                  ? null
                  : () => ref.invalidate(financingManagedProductsProvider),
              detailedError: error is FinancingCatalogueUnavailableException
                  ? null
                  : error.toString(),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  subtitle: canManage
                      ? 'Add a product to start the review and publication workflow.'
                      : 'No products are visible to your role.',
                  actionLabel: canManage ? 'Add product' : null,
                  onAction: canManage
                      ? () => _showProductForm(
                            providerOptions: providers.value ?? const [],
                          )
                      : null,
                );
              }
              final providerNames = <String, String>{
                for (final p in providers.value ?? const <FinancingProvider>[])
                  p.id: p.name,
              };
              final query = _productQuery.trim().toLowerCase();
              final filtered = rows
                  .where((product) =>
                      (_approvalFilter == null ||
                          product.approvalStatus == _approvalFilter) &&
                      (query.isEmpty ||
                          '${product.name} ${product.slug} '
                                  '${providerNames[product.providerId] ?? ''}'
                              .toLowerCase()
                              .contains(query)))
                  .toList(growable: false);

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.search_off_outlined,
                  title: 'No matching products',
                  subtitle:
                      'No product matches "${_productQuery.trim()}". Clear '
                      'the search or pick a different approval filter.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _productSearchController.clear();
                    setState(() {
                      _productQuery = '';
                      _approvalFilter = null;
                    });
                  },
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
                    providerName: providerNames[product.providerId],
                    showLifecycle: true,
                    trailing: (canManage || canReview || canPublish)
                        ? PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (action) =>
                                _handleProductAction(action, product),
                            itemBuilder: (_) => _productMenuItems(
                              product,
                              canManage: canManage,
                              canReview: canReview,
                              canPublish: canPublish,
                            ),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<PopupMenuItem<String>> _productMenuItems(
    FinancingProduct product, {
    required bool canManage,
    required bool canReview,
    required bool canPublish,
  }) {
    final status = product.approvalStatus ?? FinancingApprovalStatus.draft;
    final items = <PopupMenuItem<String>>[];

    if (canManage) {
      if (status == FinancingApprovalStatus.approved || product.isPublished) {
        items.add(const PopupMenuItem(
          value: 'reopen',
          child: Text('Reopen for editing'),
        ));
      } else {
        items.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
      }
      if (status == FinancingApprovalStatus.draft ||
          status == FinancingApprovalStatus.rejected) {
        items.add(const PopupMenuItem(
          value: 'submit',
          child: Text('Submit for review'),
        ));
      }
    }
    if (canReview && status == FinancingApprovalStatus.inReview) {
      items
        ..add(const PopupMenuItem(
          value: 'approve',
          child: Text('Approve'),
        ))
        ..add(const PopupMenuItem(
          value: 'reject',
          child: Text('Reject'),
        ));
    }
    if (canPublish) {
      if (product.isPublished) {
        items.add(const PopupMenuItem(
          value: 'unpublish',
          child: Text('Unpublish'),
        ));
      } else if (status == FinancingApprovalStatus.approved) {
        items.add(const PopupMenuItem(
          value: 'publish',
          child: Text('Publish'),
        ));
      }
    }
    return items;
  }

  Future<void> _handleProductAction(
    String action,
    FinancingProduct product,
  ) async {
    switch (action) {
      case 'edit':
        final options = ref.read(financingManagedProvidersProvider);
        await _showProductForm(
          existing: product,
          providerOptions: options.value ?? const [],
        );
      case 'reopen':
        await _run(() async {
          await ref
              .read(financingCatalogueActionsProvider)
              .reopenProduct(product.id);
          _showMessage('"${product.name}" is editable again — resubmit it for review.');
        });
      case 'submit':
        await _run(() async {
          await ref
              .read(financingCatalogueActionsProvider)
              .submitProductForReview(product.id);
          _showMessage('"${product.name}" was submitted for review.');
        });
      case 'approve':
      case 'reject':
        final approve = action == 'approve';
        final confirmed = await _confirm(
          title: approve
              ? 'Approve "${product.name}"?'
              : 'Reject "${product.name}"?',
          message: approve
              ? 'An approved product can then be published to the catalogue.'
              : 'The product returns to draft so it can be edited and resubmitted.',
          confirmLabel: approve ? 'Approve' : 'Reject',
          destructive: !approve,
        );
        if (confirmed != true) return;
        await _run(() async {
          await ref.read(financingCatalogueActionsProvider).reviewProduct(
                productId: product.id,
                approved: approve,
              );
          _showMessage(
            approve
                ? '"${product.name}" approved.'
                : '"${product.name}" rejected.',
          );
        });
      case 'publish':
        final confirmed = await _confirm(
          title: 'Publish "${product.name}"?',
          message: 'It becomes visible in the public catalogue immediately.',
          confirmLabel: 'Publish',
        );
        if (confirmed != true) return;
        await _run(() async {
          await ref
              .read(financingCatalogueActionsProvider)
              .publishProduct(product.id);
          _showMessage('"${product.name}" is live.');
        });
      case 'unpublish':
        await _run(() async {
          await ref
              .read(financingCatalogueActionsProvider)
              .unpublishProduct(product.id);
          _showMessage('"${product.name}" was removed from the public catalogue.');
        });
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E))
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ── Provider form ───────────────────────────────────────────────────────

  Future<void> _showProviderForm({FinancingProvider? existing}) async {
    final name = TextEditingController(text: existing?.name);
    final slug = TextEditingController(text: existing?.slug);
    final description = TextEditingController(text: existing?.description);
    final website = TextEditingController(text: existing?.websiteUrl);
    final email = TextEditingController(text: existing?.contactEmail);
    final phone = TextEditingController(text: existing?.contactPhone);
    final country = TextEditingController(text: existing?.countryCode ?? 'KE');
    var type = existing?.providerType ?? FinancialPartnerType.bank;
    var isActive = existing?.isActive ?? true;

    // ── Slug derivation ──────────────────────────────────────────────────
    // The slug mirrors the name while the operator has not touched it, and is
    // frozen as soon as they do. Never sent until it passes the format rules.
    var slugEdited = false;
    var syncingSlug = false;
    var lastSyncedName = existing?.name ?? '';
    var fieldError = '';
    var saving = false;

    void syncSlug() {
      if (slugEdited) return;
      if (name.text == lastSyncedName) return;
      final generated = buildFinancingSlug(name.text);
      if (generated != slug.text) {
        syncingSlug = true;
        slug.text = generated;
        syncingSlug = false;
      }
      lastSyncedName = name.text;
    }

    name.addListener(syncSlug);
    slug.addListener(() {
      if (!syncingSlug) slugEdited = true;
    });

    void disposeForm() {
      name.removeListener(syncSlug);
      for (final c in [
        name,
        slug,
        description,
        website,
        email,
        phone,
        country,
      ]) {
        c.dispose();
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SheetLifecycle(
        onDispose: disposeForm,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            return PopScope(
              canPop: !saving,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheetHeader(
                        icon: Icons.storefront_outlined,
                        title:
                            existing == null ? 'Add provider' : 'Edit provider',
                        subtitle: existing == null
                            ? 'Create a financing partner. The slug is generated '
                                'from the name and can be overridden below.'
                            : 'Update partner details. Changing the name '
                                'regenerates the slug unless you set it yourself.',
                      ),
                      const SizedBox(height: 20),
                      _label('Name *'),
                      _textField(name, hint: 'e.g. Equity Bank'),
                      const SizedBox(height: 14),
                      _label('Slug'),
                      _textField(
                        slug,
                        hint: 'auto-generated from the name',
                        helper: 'lowercase letters, numbers and hyphens',
                      ),
                      const SizedBox(height: 14),
                      _label('Type'),
                      _dropdown<FinancialPartnerType>(
                        value: type,
                        items: [
                          for (final t in FinancialPartnerType.values)
                            DropdownMenuItem(
                              value: t,
                              child: Text(partnerTypeLabel(t)),
                            ),
                        ],
                        onChanged: (v) => setSheetState(() => type = v ?? type),
                      ),
                      const SizedBox(height: 14),
                      _label('Description'),
                      _textField(description, maxLines: 3),
                      const SizedBox(height: 14),
                      _label('Website'),
                      _textField(website, hint: 'https://'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Contact email'),
                                _textField(email,
                                    keyboard: TextInputType.emailAddress),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Contact phone'),
                                _textField(phone, keyboard: TextInputType.phone),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Country code'),
                                _textField(country, hint: 'KE'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _switchCard(
                              title: 'Active',
                              subtitle: 'Visible in the catalogue',
                              value: isActive,
                              onChanged: (v) => setSheetState(() => isActive = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (fieldError.isNotEmpty) ...[
                        _inlineError(fieldError),
                        const SizedBox(height: 14),
                      ],
                      _formActions(
                        saving: saving,
                        saveLabel: 'Save provider',
                        onCancel: () {
                          if (saving) return;
                          Navigator.of(sheetContext).pop();
                        },
                        onSave: () async {
                          if (saving) return;
                          final value = name.text.trim();
                          if (value.isEmpty) {
                            setSheetState(() => fieldError = 'Name is required.');
                            return;
                          }
                          final rawSlug = slugEdited ? slug.text.trim() : null;
                          final resolvedSlug = resolveProviderSlug(
                            name: value,
                            existingSlug: existing?.slug,
                            previousName: existing?.name,
                            manualSlug: rawSlug,
                          );
                          final slugProblem = validateFinancingSlug(
                            resolvedSlug,
                            generated: rawSlug == null,
                          );
                          if (slugProblem != null) {
                            setSheetState(() => fieldError = slugProblem);
                            return;
                          }

                          setSheetState(() {
                            saving = true;
                            fieldError = '';
                          });
                          try {
                            await ref
                                .read(financingCatalogueActionsProvider)
                                .saveProvider(
                                  providerId: existing?.id,
                                  slug: resolvedSlug,
                                  name: value,
                                  providerType: type,
                                  description: description.text.trim().isEmpty
                                      ? null
                                      : description.text.trim(),
                                  websiteUrl: website.text.trim().isEmpty
                                      ? null
                                      : website.text.trim(),
                                  contactEmail: email.text.trim().isEmpty
                                      ? null
                                      : email.text.trim(),
                                  contactPhone: phone.text.trim().isEmpty
                                      ? null
                                      : phone.text.trim(),
                                  countryCode: country.text.trim().isEmpty
                                      ? null
                                      : country.text.trim(),
                                  isActive: isActive,
                                );
                            if (!sheetContext.mounted) return;
                            setSheetState(() => saving = false);
                            Navigator.of(sheetContext).pop();
                            _showMessage('Provider saved.');
                          } catch (error) {
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                saving = false;
                                fieldError = describeFinancingActionError(error);
                              });
                            } else if (mounted) {
                              _showMessage(describeFinancingActionError(error));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

  }

  // ── Product form ────────────────────────────────────────────────────────

  Future<void> _showProductForm({
    FinancingProduct? existing,
    required List<FinancingProvider> providerOptions,
  }) async {
    if (providerOptions.isEmpty) {
      _showMessage('Add a provider before creating products.');
      return;
    }

    final name = TextEditingController(text: existing?.name);
    final summary = TextEditingController(text: existing?.summary);
    final currency = TextEditingController(text: existing?.currency ?? 'KES');
    final minAmount =
        TextEditingController(text: existing?.minAmount?.toString());
    final maxAmount =
        TextEditingController(text: existing?.maxAmount?.toString());
    final rate = TextEditingController(text: existing?.interestRate?.toString());
    final minTenure =
        TextEditingController(text: existing?.minTenureDays?.toString());
    final maxTenure =
        TextEditingController(text: existing?.maxTenureDays?.toString());
    final requirements = TextEditingController(
      text: existing?.requirements.join(', ') ?? '',
    );

    var type = existing?.productType ?? FinancingProductType.loan;
    var rateType = existing?.interestRateType ?? FinancingRateType.reducingBalance;
    var providerId = existing?.providerId ??
        (providerOptions.any((p) => p.id == existing?.providerId)
            ? existing!.providerId
            : providerOptions.first.id);
    var requiresCollateral = existing?.requiresCollateral ?? false;
    var isActive = existing?.isActive ?? true;
    var fieldError = '';
    var saving = false;

    // The product form has no slug input — the value is always derived from
    // the name (or preserved when the name is untouched on an existing row).
    var slugText = existing?.slug ?? '';
    var lastSyncedName = existing?.name ?? '';
    var sheetOpen = false;
    void Function(void Function())? setSheetStateRef;

    void syncSlug() {
      if (name.text == lastSyncedName) return;
      final generated = buildFinancingSlug(name.text);
      lastSyncedName = name.text;
      if (generated != slugText) {
        slugText = generated;
        if (sheetOpen) setSheetStateRef?.call(() {});
      }
    }

    name.addListener(syncSlug);

    void disposeForm() {
      sheetOpen = false;
      name.removeListener(syncSlug);
      for (final c in [
        name,
        summary,
        currency,
        minAmount,
        maxAmount,
        rate,
        minTenure,
        maxTenure,
        requirements,
      ]) {
        c.dispose();
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SheetLifecycle(
        onDispose: disposeForm,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            sheetOpen = true;
            setSheetStateRef = setSheetState;
            return PopScope(
              canPop: !saving,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheetHeader(
                        icon: Icons.inventory_2_outlined,
                        title:
                            existing == null ? 'Add product' : 'Edit product',
                        subtitle: existing == null
                            ? 'Products start in draft and move through review '
                                'before publication.'
                            : 'Lifecycle rules decide which fields can change in '
                                'the current approval state.',
                      ),
                      const SizedBox(height: 20),
                      _label('Name *'),
                      _textField(name, hint: 'e.g. Seasonal input loan'),
                      const SizedBox(height: 14),
                      _label('Slug'),
                      _staticField(
                        slugText,
                        hint: 'auto-generated from the name',
                        helper: 'lowercase letters, numbers and hyphens',
                      ),
                      const SizedBox(height: 14),
                      _label('Provider *'),
                      _dropdown<String>(
                        value: providerOptions.any((p) => p.id == providerId)
                            ? providerId
                            : providerOptions.first.id,
                        items: [
                          for (final p in providerOptions)
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                        ],
                        onChanged: existing == null
                            ? (v) =>
                                setSheetState(() => providerId = v ?? providerId)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Type'),
                                _dropdown<FinancingProductType>(
                                  value: type,
                                  items: [
                                    for (final t in FinancingProductType.values)
                                      DropdownMenuItem(
                                          value: t, child: Text(t.label)),
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => type = v ?? type),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Rate type'),
                                _dropdown<FinancingRateType>(
                                  value: rateType,
                                  items: [
                                    for (final t in FinancingRateType.values)
                                      DropdownMenuItem(
                                          value: t, child: Text(t.label)),
                                  ],
                                  onChanged: (v) => setSheetState(
                                      () => rateType = v ?? rateType),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _label('Summary'),
                      _textField(summary, maxLines: 2),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Currency'),
                                _textField(currency),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Interest rate (%)'),
                                _textField(rate, keyboard: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Min amount'),
                                _textField(minAmount,
                                    keyboard: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Max amount'),
                                _textField(maxAmount,
                                    keyboard: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Min tenure (days)'),
                                _textField(minTenure,
                                    keyboard: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Max tenure (days)'),
                                _textField(maxTenure,
                                    keyboard: TextInputType.number),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _label('Requirements (comma separated)'),
                      _textField(requirements,
                          hint: 'National ID, Farm registration'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _switchCard(
                              title: 'Collateral',
                              subtitle: 'Security required',
                              value: requiresCollateral,
                              onChanged: (v) =>
                                  setSheetState(() => requiresCollateral = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _switchCard(
                              title: 'Active',
                              subtitle: 'Offered to customers',
                              value: isActive,
                              onChanged: (v) =>
                                  setSheetState(() => isActive = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (fieldError.isNotEmpty) ...[
                        _inlineError(fieldError),
                        const SizedBox(height: 14),
                      ],
                      _formActions(
                        saving: saving,
                        saveLabel: 'Save product',
                        onCancel: () {
                          if (saving) return;
                          Navigator.of(sheetContext).pop();
                        },
                        onSave: () async {
                          if (saving) return;
                          final value = name.text.trim();
                          if (value.isEmpty) {
                            setSheetState(
                                () => fieldError = 'Name is required.');
                            return;
                          }
                          if (existing == null && providerId.isEmpty) {
                            setSheetState(
                                () => fieldError = 'Select a provider.');
                            return;
                          }
                          final resolvedSlug = resolveProviderSlug(
                            name: value,
                            existingSlug: existing?.slug,
                            previousName: existing?.name,
                            manualSlug: null,
                          );
                          final slugProblem = validateFinancingSlug(
                            resolvedSlug,
                            generated: true,
                          );
                          if (slugProblem != null) {
                            setSheetState(() => fieldError = slugProblem);
                            return;
                          }

                          setSheetState(() {
                            saving = true;
                            fieldError = '';
                          });
                          try {
                            await ref
                                .read(financingCatalogueActionsProvider)
                                .saveProduct(
                                  productId: existing?.id,
                                  providerId:
                                      existing == null ? providerId : null,
                                  slug: resolvedSlug,
                                  name: value,
                                  productType: type,
                                  summary: summary.text.trim().isEmpty
                                      ? null
                                      : summary.text.trim(),
                                  currency: currency.text.trim().isEmpty
                                      ? null
                                      : currency.text.trim(),
                                  minAmount:
                                      double.tryParse(minAmount.text.trim()),
                                  maxAmount:
                                      double.tryParse(maxAmount.text.trim()),
                                  interestRate:
                                      double.tryParse(rate.text.trim()),
                                  interestRateType: rateType,
                                  minTenureDays:
                                      int.tryParse(minTenure.text.trim()),
                                  maxTenureDays:
                                      int.tryParse(maxTenure.text.trim()),
                                  requiresCollateral: requiresCollateral,
                                  requirements: requirements.text
                                      .split(',')
                                      .map((e) => e.trim())
                                      .where((e) => e.isNotEmpty)
                                      .toList(),
                                  isActive: isActive,
                                );
                            if (!sheetContext.mounted) return;
                            setSheetState(() => saving = false);
                            Navigator.of(sheetContext).pop();
                            _showMessage('Product saved.');
                          } catch (error) {
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                saving = false;
                                fieldError = describeFinancingActionError(error);
                              });
                            } else if (mounted) {
                              _showMessage(describeFinancingActionError(error));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

  }

  // ── Form helpers ────────────────────────────────────────────────────────

  Widget _sheetHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E7D32).withValues(alpha: 0.14),
                const Color(0xFF2E7D32).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: Colors.grey.shade700,
          ),
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    String? helper,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        helperMaxLines: 1,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

  /// Read-only value rendered like a field — used where the value is derived
  /// (the product slug) and must not be edited by hand.
  Widget _staticField(String value, {String? hint, String? helper}) {
    return InputDecorator(
      isEmpty: value.isEmpty,
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        helperMaxLines: 1,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        suffixIcon: const Icon(Icons.lock_outline, size: 16),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 38, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: value.isEmpty ? Colors.grey.shade500 : const Color(0xFF1B1B1F),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1B1B1F)),
        ),
      ),
    );
  }

  /// A `ListTile` paints its background and ink on the nearest Material, so
  /// the surface must be a Material rather than a decorated Container —
  /// otherwise Flutter raises "ListTile background color or ink splashes may
  /// be invisible".
  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: const Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// Inline validation feedback, rendered immediately above the actions so the
  /// operator never has to read a snackbar to learn why nothing happened.
  Widget _inlineError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2B8B5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: Color(0xFFB3261E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF8C1D18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formActions({
    required bool saving,
    required String saveLabel,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(saveLabel),
          ),
        ),
      ],
    );
  }
}

/// Runs [onDispose] only once the sheet subtree has actually left the tree.
///
/// `showModalBottomSheet` resolves as soon as the route is popped, which is
/// *before* the exit transition finishes. Disposing the form controllers at
/// that point trips "A TextEditingController was used after being disposed"
/// the moment the still-mounted sheet rebuilds, so disposal is deferred to a
/// microtask scheduled from `dispose()` — after every child has unmounted.
class _SheetLifecycle extends StatefulWidget {
  const _SheetLifecycle({
    required this.onDispose,
    required this.child,
  });

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_SheetLifecycle> createState() => _SheetLifecycleState();
}

class _SheetLifecycleState extends State<_SheetLifecycle> {
  @override
  void dispose() {
    final onDispose = widget.onDispose;
    scheduleMicrotask(onDispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
