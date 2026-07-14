library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/app_router_provider.dart';
import 'package:famhub_app/core/router/route_names.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// NAVIGATION SDK
/// ============================================================
///
/// Feature modules use this instead of GoRouter directly.
///
/// Usage:
///   final nav = ref.read(famhubNavigationSdkProvider);
///   nav.go(context, '/farm');
///   nav.push(context, '/marketplace');
///   nav.pop(context);
/// ============================================================
class NavigationSdk {
  final Ref _ref;

  NavigationSdk(this._ref);

  /// Navigate to a route (replaces current page in history)

  @SdkMethod(version: '1.0.0')
  void go(BuildContext context, String route) => context.go(route);

  /// Push a new route onto the navigation stack

  @SdkMethod(version: '1.0.0')
  void push(BuildContext context, String route) => context.push(route);

  /// Replace the current route (no back navigation to current)

  @SdkMethod(version: '1.0.0')
  void replace(BuildContext context, String route) =>
      context.replace(route);

  /// Pop back to the previous route
  @Deprecated('Use popWithResult() instead')

  @SdkMethod(version: '1.0.0')
  void pop(BuildContext context) {
    if (context.canPop()) context.pop();
  }

  /// Pop back with a result

  @SdkMethod(version: '1.0.0')
  void popWithResult<T>(BuildContext context, [T? result]) =>
      context.pop(result);

  /// Navigate to a module by its module key

  @SdkMethod(version: '1.0.0')
  void openModule(BuildContext context, String moduleKey) =>
      context.go('/module/$moduleKey');

  /// Navigate to the root dashboard

  @SdkMethod(version: '1.0.0')
  void openDashboard(BuildContext context) => context.go(AppRoutes.root);

  /// Navigate to settings

  @SdkMethod(version: '1.0.0')
  void openSettings(BuildContext context) => context.go(AppRoutes.settings);

  /// Navigate to notifications

  @SdkMethod(version: '1.0.0')
  void openNotifications(BuildContext context) =>
      context.go(AppRoutes.notifications);

  /// Navigate to search

  @SdkMethod(version: '1.0.0')
  void openSearch(BuildContext context) => context.go(AppRoutes.search);

  /// Navigate to home

  @SdkMethod(version: '1.0.0')
  void openHome(BuildContext context) => context.go(AppRoutes.home);
  /// Navigate to AI assistant

  @SdkMethod(version: '1.0.0')
  void openAiAssistant(BuildContext context) =>
      context.go(AppRoutes.aiAssistant);
}
/// ============================================================
/// PROVIDER: NAVIGATION SDK
/// ============================================================
@SdkProvider()
final famhubNavigationSdkProvider = Provider<NavigationSdk>((ref) {
  return NavigationSdk(ref);
});

