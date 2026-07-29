/// ============================================================
/// DYNAMIC ACTIVITY WORKFLOW SERVICE — Implementation
/// ============================================================
///
/// 🎯 PURPOSE:
///   Concrete implementation of DynamicActivityWorkflowService.
///   Contains ALL business workflows that were previously in
///   DynamicActivityExecutionPage:
///     - activity creation
///     - notes generation
///     - stock mutation logic
///     - financial recording
///     - KPI updates
///     - business validation
///     - event emission
///     - rollback preparation
///     - activity ID propagation
///
/// ✅ The page becomes a thin UI controller.
/// ============================================================
library;

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/workflow_events.dart';
import 'package:famhub_app/features/farm_management/application/services/dynamic_activity_workflow_service.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/stock_mutation_engine.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/kpi_automation_service.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/financial_recording_service.dart';

/// ============================================================
/// DYNAMIC ACTIVITY WORKFLOW SERVICE IMPLEMENTATION
/// ============================================================
class DynamicActivityWorkflowServiceImpl
    implements DynamicActivityWorkflowService {
  final FarmRepository _repository;
  final StockMutationEngine _stockEngine;
  final KpiAutomationService _kpiService;
  final FinancialRecordingService _financialService;
  final AppEventBus _eventBus;

  DynamicActivityWorkflowServiceImpl({
    required FarmRepository repository,
    required StockMutationEngine stockEngine,
    required KpiAutomationService kpiService,
    required FinancialRecordingService financialService,
    required AppEventBus eventBus,
  })  : _repository = repository,
        _stockEngine = stockEngine,
        _kpiService = kpiService,
        _financialService = financialService,
        _eventBus = eventBus;

  @override
  String? validateFormValues(
    ActivityTemplate template,
    Map<String, dynamic> formValues,
  ) {
    // Validate required attributes have values
    for (final attr in template.attributes) {
      if (attr.isRequired) {
        final value = formValues[attr.name];
        if (value == null || (value is String && value.trim().isEmpty)) {
          return '${attr.label} is required';
        }
      }
    }
    return null;
  }

  @override
  Future<WorkflowExecutionResult> executeWorkflow({
    required String farmId,
    required String fieldId,
    required String cropOrLivestockId,
    required String cropOrLivestockType,
    required ActivityTemplate template,
    required Map<String, dynamic> formValues,
    String? activityId,
  }) async {
    // Generate a unique activity ID if not provided
    // Legacy: activity ID now comes from backend via createActivity response

    // ════════════════════════════════════════════════════════════
    // STEP 1 — BUILD NOTES
    // ════════════════════════════════════════════════════════════
    final notes = _buildNotes(template, formValues);

    // ════════════════════════════════════════════════════════════
    // STEP 2 — VALIDATE HIERARCHY CONTEXT
    // ════════════════════════════════════════════════════════════
    final hierarchyValidation = _validateHierarchyContext(
      farmId: farmId,
      fieldId: fieldId,
      cropOrLivestockId: cropOrLivestockId,
      cropOrLivestockType: cropOrLivestockType,
      template: template,
    );
    if (hierarchyValidation != null) {
      return WorkflowExecutionResult(
        activityId: null,
        errorMessage: hierarchyValidation,
      );
    }

    // ════════════════════════════════════════════════════════════
    // STEP 3 — CREATE ACTIVITY (backend generates the ID)
    // ════════════════════════════════════════════════════════════
    final activity = ActivityModel(
      id: '', // Backend will auto-generate the ID
      activityTypeId: template.id,
      // UI context fields (NOT sent to backend; only for frontend context)
      fieldId: fieldId,
      cropOrLivestockId: cropOrLivestockId,
      cropOrLivestockType: cropOrLivestockType,
      performedAt: DateTime.now(),
      notes: notes,
      assetId: null,
      planId: null,
    );

    // Only documented columns are sent to the backend activities table.
    // farmId, fieldId, cropOrLivestockId, cropOrLivestockType are UI context only.
    final createdActivity = await _repository.createActivity(activity: activity);
    final backendId = createdActivity.id; // USE the backend-generated ID

    // ════════════════════════════════════════════════════════════
    // STEP 4 — STOCK MUTATION (uses backend-generated activity ID)
    // ════════════════════════════════════════════════════════════
    await _handleStockMutation(
      farmId: farmId,
      template: template,
      formValues: formValues,
      activityId: backendId,
    );

    // ════════════════════════════════════════════════════════════
    // STEP 5 — FINANCIAL RECORDING
    // ════════════════════════════════════════════════════════════
    await _handleFinancialRecording(
      farmId: farmId,
      template: template,
      formValues: formValues,
    );

    // ════════════════════════════════════════════════════════════
    // STEP 6 — KPI AUTOMATION
    // ════════════════════════════════════════════════════════════
    await _handleKpiUpdates(
      farmId: farmId,
      template: template,
      formValues: formValues,
    );

    // ════════════════════════════════════════════════════════════
    // STEP 7 — EVENT EMISSION (uses backend-generated activity ID)
    // ════════════════════════════════════════════════════════════
    _emitWorkflowEvent(
      farmId: farmId,
      fieldId: fieldId,
      cropOrLivestockId: cropOrLivestockId,
      cropOrLivestockType: cropOrLivestockType,
      template: template,
      activityId: backendId,
    );

    return WorkflowExecutionResult(activityId: backendId);
  }

  /// ============================================================
  /// VALIDATE HIERARCHY CONTEXT
  /// ============================================================
  ///
  /// Ensures the workflow is being executed within a valid hierarchy
  /// context (farm → field → crop/livestock). Returns an error message
  /// if validation fails, or null if everything is valid.
  /// ============================================================
  String? _validateHierarchyContext({
    required String farmId,
    required String fieldId,
    required String cropOrLivestockId,
    required String cropOrLivestockType,
    required ActivityTemplate template,
  }) {
    // Farm ID must always be present
    if (farmId.isEmpty) {
      return 'Farm ID is required to execute a workflow';
    }

    // Field ID must be present for crop activities
    if (template.category == 'crops' && fieldId.isEmpty) {
      return 'A field must be selected for crop activities';
    }

    // Crop/livestock ID must be present when expected
    if (template.category == 'crops' && cropOrLivestockId.isEmpty) {
      return 'A crop must be selected for crop activities';
    }
    if (template.category == 'livestock' && cropOrLivestockId.isEmpty) {
      return 'A livestock animal must be selected for livestock activities';
    }

    // Validate cropOrLivestockType matches template category
    if (cropOrLivestockType.isNotEmpty &&
        template.category == 'crops' &&
        cropOrLivestockType != 'crop') {
      return 'Crop activities require a crop context, but got $cropOrLivestockType';
    }
    if (cropOrLivestockType.isNotEmpty &&
        template.category == 'livestock' &&
        cropOrLivestockType != 'livestock') {
      return 'Livestock activities require a livestock context, but got $cropOrLivestockType';
    }

    return null; // All checks passed
  }

  /// ============================================================
  /// BUILD NOTES
  /// ============================================================
  String _buildNotes(ActivityTemplate template, Map<String, dynamic> values) {
    final notesLines = values.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    return '${template.name}\n$notesLines';
  }

  /// ============================================================
  /// STOCK MUTATION HANDLER
  /// ============================================================
  Future<void> _handleStockMutation({
    required String farmId,
    required ActivityTemplate template,
    required Map<String, dynamic> formValues,
    required String activityId,
  }) async {
    if (template.category != 'crops' && template.category != 'livestock') {
      return;
    }

    final isOutflow = template.id.contains('feeding') ||
        template.id.contains('planting') ||
        template.id.contains('spraying') ||
        template.id.contains('fertilization');
    final isInflow = template.id.contains('milking') ||
        template.id.contains('harvesting') ||
        template.id.contains('collection');

    if (isOutflow) {
      final quantity = formValues['feed_quantity'] ??
          formValues['seed_rate'] ??
          formValues['quantity'] ??
          0;
      if (quantity is num && quantity > 0) {
        final assets = await _repository.getAssets(farmId: farmId);
        final matchingAsset = assets.where((a) =>
            template.id.contains('feeding')
                ? a.assetType == 'feed' ||
                    a.assetName.toLowerCase().contains('feed')
                : a.assetType == 'input' ||
                    a.assetName.toLowerCase().contains('seed')).firstOrNull;
        if (matchingAsset != null) {
          await _stockEngine.consumeStock(
            farmId: farmId,
            assetId: matchingAsset.id,
            quantity: quantity.toDouble(),
            description: '${template.name}: stock consumption',
          );
        }
      }
    } else if (isInflow) {
      final quantity = formValues['milk_volume'] ??
          formValues['yield'] ??
          formValues['quantity'] ??
          0;
      if (quantity is num && quantity > 0) {
        final assets = await _repository.getAssets(farmId: farmId);
        final matchingAsset = assets.where((a) =>
            a.assetType == 'production' ||
            (template.id.contains('milking') &&
                a.assetName.toLowerCase().contains('milk')) ||
            (template.id.contains('harvest') && a.assetType == 'crop')).firstOrNull;
        if (matchingAsset != null) {
          await _stockEngine.addStock(
            farmId: farmId,
            assetId: matchingAsset.id,
            quantity: quantity.toDouble(),
            description: '${template.name}: production inflow',
          );
        }
      }
    }
  }

  /// ============================================================
  /// FINANCIAL RECORDING HANDLER
  /// ============================================================
  Future<void> _handleFinancialRecording({
    required String farmId,
    required ActivityTemplate template,
    required Map<String, dynamic> formValues,
  }) async {
    final costPrice = formValues['cost_price'];
    final salePrice = formValues['sale_price'] ?? formValues['income'];

    if (costPrice is num && costPrice > 0) {
      await _financialService.recordExpense(
        farmId: farmId,
        amount: costPrice.toDouble(),
        description: 'Cost for ${template.name}',
      );
    }
    if (salePrice is num && salePrice > 0) {
      await _financialService.recordIncome(
        farmId: farmId,
        amount: salePrice.toDouble(),
        description: 'Income from ${template.name}',
      );
    }
  }

  /// ============================================================
  /// KPI UPDATES HANDLER
  /// ============================================================
  Future<void> _handleKpiUpdates({
    required String farmId,
    required ActivityTemplate template,
    required Map<String, dynamic> formValues,
  }) async {
    await _kpiService.updateProductionKpis(farmId: farmId);
    await _kpiService.updateStockValueKpi(farmId: farmId);

    final costPrice = formValues['cost_price'];
    final salePrice = formValues['sale_price'] ?? formValues['income'];
    if (costPrice is num || salePrice is num) {
      await _kpiService.updateFinancialKpis(farmId: farmId);
    }
  }

  /// ============================================================
  /// EVENT EMISSION
  /// ============================================================
  void _emitWorkflowEvent({
    required String farmId,
    required String fieldId,
    required String cropOrLivestockId,
    required String cropOrLivestockType,
    required ActivityTemplate template,
    required String activityId,
  }) {
    _eventBus.emit(WorkflowEvent.completed(
      workflowName: 'dynamic_activity',
      stepName: 'execute_${template.id}',
      payload: {
        'farm_id': farmId,
        'field_id': fieldId,
        'crop_or_livestock_id': cropOrLivestockId,
        'crop_or_livestock_type': cropOrLivestockType,
        'template_id': template.id,
        'template_name': template.name,
        'category': template.category,
        'activity_id': activityId,
      },
    ));
  }

  /// ============================================================
  /// ACTIVITY ID GENERATOR
  /// ============================================================
  String _generateActivityId() {
    return 'act_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
  }

  String _randomSuffix() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
