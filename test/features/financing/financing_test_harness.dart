import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_catalogue_provider.dart';
import 'package:famhub_app/features/financing/application/providers/financing_permission_provider.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';

/// ============================================================
/// FINANCING TEST HARNESS
///
/// Hand-written fakes (no mocking package) for the Financing feature.
/// Mirrors test/features/logistics/logistics_test_harness.dart.
/// ============================================================

const EntityContext signedInContext = EntityContext(
  userId: 'user-1',
  profileId: 'profile-1',
  entityId: 'entity-1',
  roleId: 'role-1',
  isGuest: false,
  isLoading: false,
);

/// Replaces the real context engine with a fixed, signed-in context.
Override contextOverride({EntityContext context = signedInContext}) {
  return contextProvider.overrideWith(() => _FixedContextController(context));
}

class _FixedContextController extends ContextController {
  _FixedContextController(this.context);

  final EntityContext context;

  @override
  EntityContext build() => context;
}

/// Grants every Financing permission the backend check returns true for.
Override allowAllPermissions() =>
    financingPermissionCheckerProvider.overrideWithValue((key) async => true);

/// Grants only [allowed] Financing permission keys.
Override allowOnlyPermissions(Set<String> allowed) {
  return financingPermissionCheckerProvider.overrideWithValue(
    (key) async => allowed.contains(key),
  );
}

List<Override> defaultOverrides({
  required FinancingCatalogueRepository repository,
  EntityContext context = signedInContext,
  Set<String>? allowedPermissions,
}) {
  return [
    financingCatalogueRepositoryProvider.overrideWithValue(repository),
    contextOverride(context: context),
    if (allowedPermissions != null)
      allowOnlyPermissions(allowedPermissions)
    else
      allowAllPermissions(),
  ];
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  bool settle = true,
}) async {
  // The management screen and its bottom sheets are tall; give them room.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Pumps the app behind a real [GoRouter] instead of a plain `MaterialApp`.
///
/// The provider-detail back affordance branches on whether the screen has any
/// history to pop, so exercising it needs a router: one test pushes the detail
/// page from the landing (history exists), another opens it as the initial
/// location (deep link, history does not).
Future<void> pumpRoutedTestApp(
  WidgetTester tester,
  GoRouter router, {
  List<Override> overrides = const <Override>[],
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Record of a single `financing.manage_provider` call, so tests can assert
/// the exact slug the form submitted.
class SaveProviderCall {
  SaveProviderCall({
    this.providerId,
    this.slug,
    required this.name,
  });

  final String? providerId;
  final String? slug;
  final String name;
}

/// In-memory stand-in for the RPC-backed repository. Nothing is granted and
/// nothing is persisted — every method either returns a fixture or throws the
/// configured error.
class FakeFinancingCatalogueRepository
    implements FinancingCatalogueRepository {
  FakeFinancingCatalogueRepository({
    List<FinancingProvider>? managedProviders,
    List<FinancingProduct>? managedProducts,
    List<FinancingProvider>? browseProviders,
    List<FinancingProduct>? browseProducts,
  })  : managedProviders = managedProviders ?? const [],
        managedProducts = managedProducts ?? const [],
        browseProviders = browseProviders ?? const [],
        browseProducts = browseProducts ?? const [];

  List<FinancingProvider> managedProviders;
  List<FinancingProduct> managedProducts;

  /// Rows returned by the two public-view reads (landing + catalogue +
  /// provider detail, which resolves a partner from this list by slug).
  List<FinancingProvider> browseProviders;
  List<FinancingProduct> browseProducts;

  final List<SaveProviderCall> saveProviderCalls = [];

  /// When set, every `saveProvider` call runs it. Returning normally is a
  /// success; throwing propagates to the screen exactly like a backend error.
  Future<String> Function(SaveProviderCall call)? onSaveProvider;

  @override
  Future<String> saveProvider({
    String? providerId,
    String? slug,
    required String name,
    required FinancialPartnerType providerType,
    String? description,
    String? logoUrl,
    String? websiteUrl,
    String? contactEmail,
    String? contactPhone,
    String? countryCode,
    bool? isActive,
  }) async {
    final call = SaveProviderCall(
      providerId: providerId,
      slug: slug,
      name: name,
    );
    saveProviderCalls.add(call);
    final handler = onSaveProvider;
    if (handler != null) return handler(call);
    return providerId ?? 'provider-new';
  }

  @override
  Future<List<FinancingProvider>> fetchManagedProviders({
    int limit = 200,
    String? verificationStatus,
  }) async =>
      managedProviders;

  @override
  Future<List<FinancingProduct>> fetchManagedProducts({
    int limit = 200,
    String? providerId,
    String? approvalStatus,
  }) async =>
      managedProducts;

  @override
  Future<List<FinancingProvider>> fetchBrowseProviders({
    int limit = 100,
    FinancialPartnerType? providerType,
  }) async =>
      browseProviders;

  @override
  Future<List<FinancingProduct>> fetchBrowseProducts({
    int limit = 200,
    String? providerId,
    FinancingProductType? productType,
  }) async =>
      providerId == null
          ? browseProducts
          : browseProducts
              .where((p) => p.providerId == providerId)
              .toList(growable: false);

  @override
  Future<String> verifyProvider({
    required String providerId,
    required FinancingVerificationStatus status,
    String? notes,
  }) async =>
      providerId;

  @override
  Future<String> saveProduct({
    String? productId,
    String? providerId,
    String? slug,
    required String name,
    required FinancingProductType productType,
    String? summary,
    String? description,
    String? currency,
    double? minAmount,
    double? maxAmount,
    double? interestRate,
    FinancingRateType? interestRateType,
    int? minTenureDays,
    int? maxTenureDays,
    bool? requiresCollateral,
    List<String>? requirements,
    bool? isActive,
  }) async =>
      productId ?? 'product-new';

  @override
  Future<String> reopenProduct({required String productId}) async => productId;

  @override
  Future<String> submitProductForReview({required String productId}) async =>
      productId;

  @override
  Future<String> reviewProduct({
    required String productId,
    required bool approved,
    String? notes,
  }) async =>
      productId;

  @override
  Future<String> publishProduct({required String productId}) async =>
      productId;

  @override
  Future<String> unpublishProduct({required String productId}) async =>
      productId;
}
