/// ============================================================
/// WORKFLOW SERVICE PROVIDER
/// ============================================================
///
/// Provides DynamicActivityWorkflowService via Riverpod.
/// Wires up all dependencies: repository, stock engine,
/// KPI service, financial service, and event bus.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/event_bus_provider.dart';
import 'package:famhub_app/features/farm_management/application/services/dynamic_activity_workflow_service.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/operational_services_provider.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/dynamic_activity_workflow_service_impl.dart';

/// Provider for the DynamicActivityWorkflowService.
/// Wires up all required dependencies.
final dynamicActivityWorkflowServiceProvider =
    Provider<DynamicActivityWorkflowService>((ref) {
  final repository = ref.read(farmRepositoryProvider);
  final stockEngine = ref.read(stockMutationEngineProvider);
  final kpiService = ref.read(kpiAutomationServiceProvider);
  final financialService = ref.read(financialRecordingServiceProvider);
  final eventBus = ref.read(eventBusProvider);

  return DynamicActivityWorkflowServiceImpl(
    repository: repository,
    stockEngine: stockEngine,
    kpiService: kpiService,
    financialService: financialService,
    eventBus: eventBus,
  );
});
