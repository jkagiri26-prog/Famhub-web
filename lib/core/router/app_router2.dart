import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context_engine/context_provider.dart';
import 'route_names.dart';
import 'route_guards.dart';
import 'route_notifier.dart';

// Pages (replace with real ones later)
import '../../app_shell/guest/guest_homepage.dart';
import '../../features/marketplace/presentation/pages/marketplace_page.dart';
import '../../dashboard/host/unified_dashboard_host.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routeNotifierProvider);

  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    refreshListenable: notifier,

    initialLocation: AppRoutes.guestHome,

    redirect: (context, state) {
      final ctx = ref.read(contextProvider);
      final location = state.uri.toString();

      // 🌍 GLOBAL RULES

      // If guest trying to access protected routes
      if (ctx.isGuest) {
        if (location.startsWith('/dashboard') ||
            location.startsWith('/marketplace')) {
          return AppRoutes.guestHome;
        }
      }

      // If logged in user trying to access login/signup
      if (!ctx.isGuest &&
          (location == AppRoutes.login ||
              location == AppRoutes.signup)) {
        return AppRoutes.dashboard;
      }

      return null;
    },

    routes: [
      /// 🌍 GUEST HOME
      GoRoute(
        path: AppRoutes.guestHome,
        builder: (context, state) => const GuestHomePage(),
      ),

      /// 🔐 LOGIN
      GoRoute(
        path: AppRoutes.login,
        redirect: (context, state) =>
            RouteGuards.guestOnly(ref),
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login Page'))),
      ),

      /// 🔐 SIGNUP
      GoRoute(
        path: AppRoutes.signup,
        redirect: (context, state) =>
            RouteGuards.guestOnly(ref),
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Signup Page'))),
      ),

      /// 📊 DASHBOARD
      GoRoute(
        path: AppRoutes.dashboard,
        redirect: (context, state) =>
            RouteGuards.authRequired(ref),
        builder: (context, state) =>
            const UnifiedDashboardHost(),
      ),

      /// 🛒 MARKETPLACE (role-aware example)
      GoRoute(
        path: AppRoutes.marketplace,
        redirect: (context, state) =>
            RouteGuards.authRequired(ref),
        builder: (context, state) =>
            const MarketplacePage(),
      ),

      /// ❌ 404
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('404'))),
      ),
    ],
  );
});