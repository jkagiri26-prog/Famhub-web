/// ============================================================
/// ORGANIZATION RUNTIME PROVIDER — ENGINE PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/organization_runtime/application/ = application layer
///
/// Provides the OrganizationRuntimeEngine via Riverpod.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/organization_runtime/application/organization_runtime_engine.dart';
import 'package:famhub_app/core/organization_runtime/infrastructure/organization_runtime_repository.dart';

/// ============================================================
/// PROVIDER: ORGANIZATION RUNTIME ENGINE
/// ============================================================
///
/// Provides the OrganizationRuntimeEngine backed by the repository.
/// ============================================================
final organizationRuntimeEngineProvider =
    Provider<OrganizationRuntimeEngine>((ref) {
  final repository = ref.watch(organizationRuntimeRepositoryProvider);
  return OrganizationRuntimeEngine(repository: repository);
});
