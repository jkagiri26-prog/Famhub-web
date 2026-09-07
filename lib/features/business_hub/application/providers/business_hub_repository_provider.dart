/// ============================================================
/// BUSINESS HUB — REPOSITORY PROVIDER
/// ============================================================
///
/// 🧠 SESSION-AWARE:
///   - Guest / unauthenticated users → demo repository (sample data)
///   - Authenticated users → BusinessHubRepositoryImpl (Supabase)
///
/// Widgets never know which implementation they receive.
/// No guest/demo logic exists in any widget.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/business_hub/domain/repositories/business_hub_repository.dart';
import 'package:famhub_app/features/business_hub/infrastructure/repositories/business_hub_repository_impl.dart';
import 'package:famhub_app/shared/demo/demo_business_hub_repository.dart';

final businessHubRepositoryProvider = Provider<BusinessHubRepository>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  if (!isAuthenticated) {
    return DemoBusinessHubRepository();
  }

  return BusinessHubRepositoryImpl();
});
