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
///   The Phase 1 migration registers the keys but seeds no role assignment,
///   so an unseeded backend renders the locked state below rather than data.
/// - Writes are RPC-only; no direct table access exists in the contract.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_management_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_permission_provider.dart';
import 'package:famhub_app/features/financing/config/permissions.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_product_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_provider_card_widget.dart';
import 'package:famhub_app/features/financing/presentation/widgets/financing_status_chip_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          const ModuleHeaderWidget(
            title: 'Catalogue Management',
            subtitle: 'Providers • Verification • Product lifecycle',
            trailingIcon: Icons.manage_accounts_outlined,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [Tab(text: 'Providers'), Tab(text: 'Products')],
          ),
          const SizedBox(height: 12),
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
        if (canManage)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showProviderForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add provider'),
            ),
          ),
        const SizedBox(height: 8),
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
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final provider = rows[index];
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
        if (canManage)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showProductForm(
                providerOptions: providers.value ?? const [],
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add product'),
            ),
          ),
        const SizedBox(height: 8),
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
              final names = <String, String>{
                for (final p in providers.value ?? const <FinancingProvider>[])
                  p.id: p.name,
              };
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = rows[index];
                  return FinancingProductCardWidget(
                    product: product,
                    providerName: names[product.providerId],
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Add provider' : 'Edit provider',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _label('Name *'),
                _textField(name, hint: 'e.g. Equity Bank'),
                const SizedBox(height: 12),
                _label('Type'),
                DropdownButton<FinancialPartnerType>(
                  isExpanded: true,
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
                const SizedBox(height: 12),
                _label('Slug (lowercase-with-dashes)'),
                _textField(slug, hint: 'left blank — the backend derives it'),
                const SizedBox(height: 12),
                _label('Description'),
                _textField(description, maxLines: 3),
                const SizedBox(height: 12),
                _label('Website'),
                _textField(website, hint: 'https://'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Contact email'),
                          _textField(email, keyboard: TextInputType.emailAddress),
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
                const SizedBox(height: 12),
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
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active', style: TextStyle(fontSize: 13)),
                        value: isActive,
                        onChanged: (v) => setSheetState(() => isActive = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final value = name.text.trim();
                      if (value.isEmpty) {
                        _showMessage('Name is required.');
                        return;
                      }
                      final navigator = Navigator.of(sheetContext);
                      navigator.pop();
                      await _run(() async {
                        await ref
                            .read(financingCatalogueActionsProvider)
                            .saveProvider(
                              providerId: existing?.id,
                              slug: slug.text.trim().isEmpty
                                  ? null
                                  : slug.text.trim(),
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
                        _showMessage('Provider saved.');
                      });
                    },
                    child: const Text('Save provider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final c in [name, slug, description, website, email, phone, country]) {
      c.dispose();
    }
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Add product' : 'Edit product',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _label('Name *'),
                _textField(name, hint: 'e.g. Seasonal input loan'),
                const SizedBox(height: 12),
                _label('Provider *'),
                DropdownButton<String>(
                  isExpanded: true,
                  value: providerOptions.any((p) => p.id == providerId)
                      ? providerId
                      : providerOptions.first.id,
                  items: [
                    for (final p in providerOptions)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: existing == null
                      ? (v) => setSheetState(() => providerId = v ?? providerId)
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Type'),
                          DropdownButton<FinancingProductType>(
                            isExpanded: true,
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
                          DropdownButton<FinancingRateType>(
                            isExpanded: true,
                            value: rateType,
                            items: [
                              for (final t in FinancingRateType.values)
                                DropdownMenuItem(
                                    value: t, child: Text(t.label)),
                            ],
                            onChanged: (v) =>
                                setSheetState(() => rateType = v ?? rateType),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Summary'),
                _textField(summary, maxLines: 2),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Min amount'),
                          _textField(minAmount, keyboard: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Max amount'),
                          _textField(maxAmount, keyboard: TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Min tenure (days)'),
                          _textField(minTenure, keyboard: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Max tenure (days)'),
                          _textField(maxTenure, keyboard: TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Requirements (comma separated)'),
                _textField(requirements,
                    hint: 'National ID, Farm registration'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      const Text('Collateral required', style: TextStyle(fontSize: 13)),
                  value: requiresCollateral,
                  onChanged: (v) => setSheetState(() => requiresCollateral = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active', style: TextStyle(fontSize: 13)),
                  value: isActive,
                  onChanged: (v) => setSheetState(() => isActive = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final value = name.text.trim();
                      if (value.isEmpty) {
                        _showMessage('Name is required.');
                        return;
                      }
                      if (existing == null && providerId.isEmpty) {
                        _showMessage('Select a provider.');
                        return;
                      }
                      final navigator = Navigator.of(sheetContext);
                      navigator.pop();
                      await _run(() async {
                        await ref
                            .read(financingCatalogueActionsProvider)
                            .saveProduct(
                              productId: existing?.id,
                              providerId:
                                  existing == null ? providerId : null,
                              name: value,
                              productType: type,
                              summary: summary.text.trim().isEmpty
                                  ? null
                                  : summary.text.trim(),
                              currency: currency.text.trim().isEmpty
                                  ? null
                                  : currency.text.trim(),
                              minAmount: double.tryParse(minAmount.text.trim()),
                              maxAmount: double.tryParse(maxAmount.text.trim()),
                              interestRate: double.tryParse(rate.text.trim()),
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
                        _showMessage('Product saved.');
                      });
                    },
                    child: const Text('Save product'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

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

  // ── Form helpers ────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
