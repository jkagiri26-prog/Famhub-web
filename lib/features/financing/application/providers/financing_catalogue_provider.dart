/// ============================================================
/// FINANCING CATALOGUE — BROWSE PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Provide the repository dependency for the whole feature.
///   - Expose the permission-free browse reads (public views) and the
///     permission-gated management reads as async providers.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - UI never reaches Supabase directly.
///   - No provider invents data: loading, empty, error and
///     "not deployed yet" are all explicit states.
///   - Guest sessions resolve to an empty list rather than a failed call.
///
/// ❌ Does NOT:
///   - Enable the Finance module or seed permissions
///   - Fall back to mock/cached rows
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/financing/domain/models/financing_catalogue_models.dart';
import 'package:famhub_app/features/financing/domain/repositories/financing_catalogue_repository.dart';
import 'package:famhub_app/features/financing/infrastructure/data_sources/financing_catalogue_remote_data_source.dart';
import 'package:famhub_app/features/financing/infrastructure/repositories/financing_catalogue_repository_impl.dart';

/// Repository layer — UI never reaches Supabase directly.
final financingCatalogueRepositoryProvider =
    Provider<FinancingCatalogueRepository>((ref) {
  return FinancingCatalogueRepositoryImpl(
    dataSource: FinancingCatalogueRemoteDataSource(),
  );
});

/// Verified, active providers from `financing.public_financial_providers`.
final financingBrowseProvidersProvider =
    FutureProvider<List<FinancingProvider>>((ref) async {
  final context = ref.watch(contextProvider);
  if (context.isGuest) return const [];
  return ref.read(financingCatalogueRepositoryProvider).fetchBrowseProviders();
});

/// Approved + published products from `financing.public_financial_products`.
final financingBrowseProductsProvider =
    FutureProvider<List<FinancingProduct>>((ref) async {
  final context = ref.watch(contextProvider);
  if (context.isGuest) return const [];
  return ref.read(financingCatalogueRepositoryProvider).fetchBrowseProducts();
});

/// Products of a single provider, used by the provider detail screen.
/// The argument is the public view's `provider_id`.
final financingProviderProductsProvider =
    FutureProvider.family<List<FinancingProduct>, String>((ref, providerId) async {
  final context = ref.watch(contextProvider);
  if (context.isGuest) return const [];
  if (providerId.isEmpty) return const [];
  return ref
      .read(financingCatalogueRepositoryProvider)
      .fetchBrowseProducts(providerId: providerId);
});
