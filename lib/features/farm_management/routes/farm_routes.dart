
import 'package:go_router/go_router.dart';

import '../presentation/pages/activities_page.dart';
import '../presentation/pages/add_farm_page.dart';
import '../presentation/pages/assets_page.dart';
import '../presentation/pages/crops_page.dart';
import '../presentation/pages/farm_dashboard_page.dart';
import '../presentation/pages/farm_details_view.dart';
import '../presentation/pages/farm_list_view.dart';
import '../presentation/pages/farms_page.dart';
import '../presentation/pages/fields_page.dart';
import '../presentation/pages/livestock_page.dart';
import '../presentation/pages/production_page.dart';

class FarmRoutes {
  static final List<GoRoute> routes = [
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmsPage(),
      routes: [
        GoRoute(
          path: 'list',
          builder: (context, state) => const FarmListView(),
        ),
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddFarmPage(), // Updated to AddFarmPage
        ),
        GoRoute(
          path: ':farmId',
          builder: (context, state) => FarmDetailsView(
            farmId: state.pathParameters['farmId']!,
          ),
          routes: [
            GoRoute(
              path: 'dashboard',
              builder: (context, state) => const FarmDashboardPage(),
            ),
            GoRoute(
              path: 'activities',
              builder: (context, state) => const ActivitiesPage(),
            ),
            GoRoute(
              path: 'production',
              builder: (context, state) => const ProductionPage(),
            ),
            GoRoute(
              path: 'livestock',
              builder: (context, state) => const LivestockPage(),
            ),
            GoRoute(
              path: 'crops',
              builder: (context, state) => const CropsPage(),
            ),
            GoRoute(
              path: 'fields',
              builder: (context, state) => const FieldsPage(),
            ),
            GoRoute(
              path: 'assets',
              builder: (context, state) => const AssetsPage(),
            ),
          ],
        ),
      ],
    ),
  ];
}
