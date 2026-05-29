import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context_engine/providers/context_provider.dart';
import 'route_names.dart';

class RouteGuards {
  /// Guest-only routes (login, signup)
  static String? guestOnly(WidgetRef ref) {
    final ctx = ref.read(contextProvider);

    if (!ctx.isGuest) {
      return AppRoutes.dashboard;
    }

    return null;
  }

  /// Requires authentication
  static String? authRequired(WidgetRef ref) {
    final ctx = ref.read(contextProvider);

    if (ctx.isGuest) {
      return AppRoutes.guestHome;
    }

    return null;
  }

  /// Role-based guard
  static String? roleRequired(
    WidgetRef ref,
    List<String> roles,
  ) {
    final ctx = ref.read(contextProvider);

    if (ctx.isGuest) {
      return AppRoutes.guestHome;
    }

    if (!roles.contains(ctx.role)) {
      return AppRoutes.dashboard;
    }

    return null;
  }

  /// Entity required
  static String? entityRequired(WidgetRef ref) {
    final ctx = ref.read(contextProvider);

    if (ctx.entityId == null) {
      return AppRoutes.dashboard;
    }

    return null;
  }
}