import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/farm_repository_impl.dart';

/// Provider exposing FarmRepository interface.
/// Implementation uses Supabase-backed FarmRepositoryImpl.
/// Can be swapped for testing/mock implementations.
final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  return FarmRepositoryImpl();
});