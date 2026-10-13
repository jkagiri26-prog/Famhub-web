/// ============================================================
/// FINANCING — ROUTE INTEGRITY
/// ============================================================
///
/// Two things are asserted here:
///
///   1. Route resolution. The real `DynamicRouteRegistrar` is asked to build
///      the router from a Finance-enabled runtime module, and each finance
///      location is matched against it. This is what makes a browser refresh
///      and a pasted deep link land on the right screen — no widget is pumped,
///      so the shell is never constructed.
///
///   2. Direct navigation of the provider-detail screen, including the
///      missing-provider case a stale deep link produces.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/features/financing/domain/models/finance_models.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/presentation/pages/financing_provider_detail_page.dart';

import 'financing_test_harness.dart';

/// Builds the real router the way `appRouterProvider` does: only the enabled
/// modules that survived the composition engine are handed to the registrar.
GoRouter _financeRouter({bool includeFinance = true}) {
  ModulePageRegistry.clear();
  bootstrapModulePageBuilders();
  addTearDown(ModulePageRegistry.clear);
  return DynamicRouteRegistrar.buildRouter([
    if (includeFinance)
      const RuntimeModule(
        moduleId: 'finance',
        displayName: 'Finance',
        route: '/finance',
        isEnabled: true,
      ),
    const RuntimeModule(
      moduleId: 'marketplace',
      displayName: 'Marketplace',
      route: '/marketplace',
      isEnabled: true,
    ),
  ]);
}

/// Walks to the leaf page the shell renders for [location], or null when the
/// location is unroutable. Shell children are nested inside the
/// `ShellRouteMatch`, so this mirrors the route the Navigator actually builds.
GoRoute? _leafRoute(GoRouter router, String location) {
  final match = router.configuration.findMatch(Uri.parse(location));
  if (match.error != null || match.matches.isEmpty) return null;
  RouteMatchBase leaf = match.matches.last;
  while (leaf is ShellRouteMatch) {
    leaf = leaf.matches.last;
  }
  return leaf.route is GoRoute ? leaf.route as GoRoute : null;
}

/// The provider slug the router captured for [location], or null when the
/// location is unroutable.
String? _detailSlug(GoRouter router, String location) {
  final match = router.configuration.findMatch(Uri.parse(location));
  if (match.error != null || match.matches.isEmpty) return null;
  return match.pathParameters['slug'];
}

/// A minimal router carrying the two finance locations the back affordance
/// moves between.
///
/// This deliberately does not build the app shell — the shell is exercised by
/// the resolution group above. Here we only need a real router so that the
/// detail page can tell "popped from a list" apart from "opened by a deep
/// link", which is the whole point of the fallback. Each route is wrapped in
/// the `Scaffold` the real shell supplies, so the page's own widgets (which
/// never carry one) have the `Material` ancestor they expect.
GoRouter _backRouter({required String initialLocation}) {
  Widget shell(Widget child) => Scaffold(body: child);

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.finance,
        name: AppRoutes.financeName,
        builder: (_, __) =>
            shell(const Center(child: Text('finance-landing'))),
      ),
      GoRoute(
        path: AppRoutes.financingProviderDetail,
        name: AppRoutes.financingProviderDetailName,
        builder: (_, state) => shell(
          FinancingProviderDetailPage(
            slug: state.pathParameters['slug'] ?? '',
          ),
        ),
      ),
    ],
  );
}

/// The on-screen back control.
///
/// Asserted structurally rather than through the semantics tree: the
/// accessibility property that matters here is that the control is a real
/// focusable button carrying a visible "Back" label — not an unlabelled icon
/// — and `TextButton` + descendant text proves exactly that.
Finder _backButton(WidgetTester tester) {
  return find.descendant(
    of: find.byType(TextButton),
    matching: find.text('Back'),
  );
}

/// The populated catalogue the detail page resolves its slug against.
FakeFinancingCatalogueRepository _catalogueRepository() {
  return FakeFinancingCatalogueRepository(
    browseProviders: [
      _provider(id: 'provider-1', slug: 'agrico-sacco', name: 'Agrico Sacco'),
    ],
    browseProducts: [
      _product(
        id: 'product-1',
        providerId: 'provider-1',
        slug: 'inputs-loans',
        name: 'Inputs loans',
      ),
    ],
  );
}

FinancingProvider _provider({
  required String id,
  required String slug,
  required String name,
}) {
  return FinancingProvider(
    id: id,
    slug: slug,
    name: name,
    providerType: FinancialPartnerType.sacco,
    description: 'Farmers savings and credit.',
    websiteUrl: 'www.agrico.com',
    countryCode: 'KE',
    isActive: true,
    verificationStatus: FinancingVerificationStatus.verified,
  );
}

FinancingProduct _product({
  required String id,
  required String providerId,
  required String slug,
  required String name,
}) {
  return FinancingProduct(
    id: id,
    providerId: providerId,
    slug: slug,
    name: name,
    productType: FinancingProductType.loan,
    isActive: true,
    isPublished: true,
  );
}

void main() {
  group('Finance route resolution (real DynamicRouteRegistrar)', () {
    test('every registered finance location resolves to its own screen', () {
      final router = _financeRouter();

      expect(
        _leafRoute(router, AppRoutes.finance)?.name,
        AppRoutes.financeName,
      );
      expect(
        _leafRoute(router, AppRoutes.financingCatalog)?.name,
        AppRoutes.financingCatalogName,
      );
      expect(
        _leafRoute(router, AppRoutes.financingManagement)?.name,
        AppRoutes.financingManagementName,
      );
      expect(
        _leafRoute(
          router,
          AppRoutes.financingProviderLocation('agrico-sacco'),
        )?.name,
        AppRoutes.financingProviderDetailName,
      );
    });

    test('the provider-detail route passes the slug to the page', () {
      final router = _financeRouter();

      expect(
        _detailSlug(
          router,
          AppRoutes.financingProviderLocation('agrico-sacco'),
        ),
        'agrico-sacco',
      );

      // Slugs are CHECK-constrained to `^[a-z0-9]+(-[a-z0-9]+)*$`, so a
      // multi-segment slug must stay ONE path segment and never swallow a
      // sibling route.
      expect(
        _detailSlug(router, AppRoutes.financingProviderLocation('a-b-c')),
        'a-b-c',
      );

      expect(
        _leafRoute(router, AppRoutes.financingProviderLocation('a-b-c'))?.path,
        '/finance/providers/:slug',
      );
    });

    test('unimplemented finance paths are NOT routed', () {
      final router = _financeRouter();

      // Declared in the module descriptor before this task; these features
      // do not exist, so nothing may claim to serve them.
      expect(_leafRoute(router, '/finance/loans/request'), isNull);
      expect(_leafRoute(router, '/finance/payment'), isNull);
      expect(
        router.configuration
            .findMatch(Uri.parse('/finance/loans/request'))
            .error,
        isNotNull,
      );
    });

    test('a module list without finance exposes none of its pages', () {
      // A disabled or access-denied module never reaches the registrar: the
      // composition engine drops it upstream (ModuleAccessFilter) and
      // `appRouterProvider` hands the registrar only the survivors. What that
      // means for these sub-pages is that they must be registered inside the
      // module loop, not as static routes — otherwise an app whose finance
      // module is off would still serve /finance/catalogue.
      final router = _financeRouter(includeFinance: false);

      expect(_leafRoute(router, AppRoutes.finance), isNull);
      expect(_leafRoute(router, AppRoutes.financingCatalog), isNull);
      expect(_leafRoute(router, AppRoutes.financingManagement), isNull);
      expect(
        _leafRoute(
          router,
          AppRoutes.financingProviderLocation('agrico-sacco'),
        ),
        isNull,
      );

      // An unrelated module that is still enabled keeps working.
      expect(_leafRoute(router, AppRoutes.marketplace), isNotNull);
    });
  });

  group('Provider detail — direct navigation', () {
    testWidgets('resolves the partner by slug and lists its products',
        (tester) async {
      final repository = FakeFinancingCatalogueRepository(
        browseProviders: [
          _provider(
            id: 'provider-1',
            slug: 'agrico-sacco',
            name: 'Agrico Sacco',
          ),
        ],
        browseProducts: [
          _product(
            id: 'product-1',
            providerId: 'provider-1',
            slug: 'inputs-loans',
            name: 'Inputs loans',
          ),
        ],
      );

      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'agrico-sacco'),
        overrides: defaultOverrides(repository: repository),
      );

      expect(find.text('Agrico Sacco'), findsOneWidget);
      expect(find.text('SACCO'), findsWidgets);
      // SectionHeaderWidget renders its title uppercased.
      expect(find.text('AVAILABLE PRODUCTS'), findsOneWidget);
      expect(find.text('Inputs loans'), findsOneWidget);
    });

    testWidgets(
        'a slug that is not in the catalogue renders a not-found state '
        'instead of an empty shell', (tester) async {
      final repository = FakeFinancingCatalogueRepository(
        browseProviders: [
          _provider(
            id: 'provider-1',
            slug: 'agrico-sacco',
            name: 'Agrico Sacco',
          ),
        ],
      );

      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'partner-that-was-unpublished'),
        overrides: defaultOverrides(repository: repository),
      );

      expect(find.text('Provider not found'), findsOneWidget);
      expect(find.text('Agrico Sacco'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a guest session is locked, not blank', (tester) async {
      final repository = FakeFinancingCatalogueRepository();

      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'agrico-sacco'),
        overrides: defaultOverrides(
          repository: repository,
          context: const EntityContext(
            userId: 'guest',
            profileId: '',
            entityId: '',
            roleId: '',
            isGuest: true,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Provider locked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Provider detail — back affordance', () {
    testWidgets('pops the GoRouter history back to the Finance landing',
        (tester) async {
      final router = _backRouter(initialLocation: AppRoutes.finance);

      await pumpRoutedTestApp(
        tester,
        router,
        overrides: defaultOverrides(repository: _catalogueRepository()),
      );
      expect(find.text('finance-landing'), findsOneWidget);

      // In-app tap, exactly as the catalogue issues it.
      router.push(AppRoutes.financingProviderLocation('agrico-sacco'));
      await tester.pumpAndSettle();

      expect(find.text('Agrico Sacco'), findsOneWidget);
      expect(find.text('finance-landing'), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('finance-landing'), findsOneWidget);
      expect(find.text('Agrico Sacco'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.finance);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'falls back to the Finance landing when opened by a deep link',
        (tester) async {
      // Nothing was pushed — this is the first route on the stack, so there
      // is no history to pop and the fallback must carry the user out.
      final router = _backRouter(
        initialLocation: AppRoutes.financingProviderLocation('agrico-sacco'),
      );

      await pumpRoutedTestApp(
        tester,
        router,
        overrides: defaultOverrides(repository: _catalogueRepository()),
      );
      expect(find.text('Agrico Sacco'), findsOneWidget);
      expect(find.text('finance-landing'), findsNothing);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('finance-landing'), findsOneWidget);
      expect(find.text('Agrico Sacco'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.finance);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is offered and labelled when the provider resolves',
        (tester) async {
      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'agrico-sacco'),
        overrides: defaultOverrides(repository: _catalogueRepository()),
      );

      expect(_backButton(tester), findsOneWidget);
      expect(find.text('Agrico Sacco'), findsOneWidget);
    });

    testWidgets(
        'is offered when the slug is stale, so a dead deep link is escapable',
        (tester) async {
      // A partner can be unpublished, suspended or re-slugged at any time;
      // the not-found state must not strand the user either.
      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'partner-that-left'),
        overrides: defaultOverrides(repository: _catalogueRepository()),
      );

      expect(_backButton(tester), findsOneWidget);
      expect(find.text('Provider not found'), findsOneWidget);
    });

    testWidgets('is offered when the session is a guest', (tester) async {
      await pumpTestApp(
        tester,
        const FinancingProviderDetailPage(slug: 'agrico-sacco'),
        overrides: defaultOverrides(
          repository: FakeFinancingCatalogueRepository(),
          context: const EntityContext(
            userId: 'guest',
            profileId: '',
            entityId: '',
            roleId: '',
            isGuest: true,
            isLoading: false,
          ),
        ),
      );

      expect(_backButton(tester), findsOneWidget);
      expect(find.text('Provider locked'), findsOneWidget);
    });
  });
}
