import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/module_service.dart';
import '../../system/modules_control/module_definition.dart';

final moduleServiceProvider = Provider((ref) => ModuleService());

final moduleProvider = FutureProvider<List<Module>>((ref) async {
  final service = ref.read(moduleServiceProvider);
  return service.getActiveModules();
});