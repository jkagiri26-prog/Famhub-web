import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/farm_repository_impl.dart';
import 'package:famhub_app/shared/demo/demo_farm_repository.dart';

/// Provider exposing FarmRepository interface.
///
/// 🧠 SESSION-AWARE:
///   - Guest / unauthenticated users → DemoFarmRepository (sample data)
///   - Authenticated users → FarmRepositoryImpl (Supabase)
///
/// Widgets never know which implementation they receive.
/// No guest/demo logic exists in any widget.
final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  final session = ref.watch(sessionProvider);

  if (session.isGuest || !session.isAuthenticated) {
    return DemoFarmRepository();
  }

  return FarmRepositoryImpl();
});