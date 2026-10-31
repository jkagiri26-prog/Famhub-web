import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';

void main() {
  group('WorkspaceDashboardCatalog.landingRouteFor', () {
    test('maps canonical workspace types to their landing routes', () {
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('farmer'),
        AppRoutes.farm,
      );
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('trader'),
        AppRoutes.trader,
      );
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('admin'),
        AppRoutes.admin,
      );
    });

    test('normalizes workspace aliases before selecting a route', () {
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('Trader / Retailer'),
        AppRoutes.trader,
      );
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('Administration'),
        AppRoutes.admin,
      );
    });

    test('keeps unmapped workspace types on the root dashboard', () {
      expect(
        WorkspaceDashboardCatalog.landingRouteFor('institution'),
        AppRoutes.root,
      );
      expect(
        WorkspaceDashboardCatalog.landingRouteFor(null),
        AppRoutes.root,
      );
    });
  });
}
