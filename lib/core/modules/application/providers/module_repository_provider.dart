import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/repositories/module_repository.dart';
import '../domain/models/system_module.dart';
import '../application/services/module_governance_service.dart';

final moduleRepositoryProvider =
    Provider((ref) => ModuleRepository());

final moduleGovernanceServiceProvider =
    Provider((ref) => ModuleGovernanceService());

final enabledModulesProvider =
    FutureProvider<List<SystemModule>>((ref) async {
  final repo = ref.watch(moduleRepositoryProvider);
  final governance = ref.watch(moduleGovernanceServiceProvider);

  final modules = await repo.fetchEnabledModules();

  return governance.applyRules(modules);
});