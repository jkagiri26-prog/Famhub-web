/// ============================================================
/// REPOSITORY SWITCH PROVIDER — Routes between demo & Supabase repos
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/demo/ = reusable demo data repositories
///
/// ✅ Responsibilities:
///   - Watch session state
///   - Provide demo repositories when guest, real repos when authenticated
///   - Single provider that all widgets use — no guest logic in widgets
/// ============================================================
library famhub_app.shared.demo.repository_switch_provider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/farm_repository_impl.dart';
import 'package:famhub_app/features/marketplace/domain/repositories/marketplace_repository.dart';
import 'package:famhub_app/features/marketplace/infrastructure/repositories/marketplace_repository_impl.dart';
import 'package:famhub_app/features/marketplace/infrastructure/data_sources/marketplace_remote_data_source.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/shared/demo/demo_farm_repository.dart';
import 'package:famhub_app/shared/demo/demo_marketplace_repository.dart';

/// FarmRepository provider that switches between demo and Supabase.
final switchingFarmRepositoryProvider = Provider<FarmRepository>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return DemoFarmRepository();
  }
  return FarmRepositoryImpl();
});

/// MarketplaceRepository provider that switches between demo and Supabase.
final switchingMarketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    return DemoMarketplaceRepository();
  }
  final dataSource = ref.watch(marketplaceRemoteDataSourceProvider);
  return MarketplaceRepositoryImpl(dataSource);
});

