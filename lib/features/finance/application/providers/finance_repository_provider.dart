/// ============================================================
/// FINANCE — REPOSITORY PROVIDER
/// ============================================================
///
/// UI and read providers never reach Supabase directly. This is the single
/// composition point for the Finance data source and repository.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/finance/domain/repositories/finance_repository.dart';
import 'package:famhub_app/features/finance/infrastructure/data_sources/finance_remote_data_source.dart';
import 'package:famhub_app/features/finance/infrastructure/repositories/finance_repository_impl.dart';

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>((
  ref,
) {
  return FinanceRemoteDataSource();
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final dataSource = ref.watch(financeRemoteDataSourceProvider);
  return FinanceRepositoryImpl(dataSource: dataSource);
});
