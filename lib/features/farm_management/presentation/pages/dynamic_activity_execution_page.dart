// ignore: dangling_library_doc_comments
/// ============================================================
/// DYNAMIC ACTIVITY EXECUTION PAGE
/// ============================================================
///
/// 🧠 SECTION 5 — DYNAMIC ACTIVITY ENGINE
///
/// This page executes agricultural workflows WITHOUT hardcoded forms.
/// It uses the DynamicActivityFormRenderer and WorkflowProgressEngine
/// to dynamically render forms based on activity templates.
///
/// SUPPORTED WORKFLOWS:
/// - Maize planting, dairy milking, poultry feeding
/// - Avocado irrigation, fish feeding, horticulture
/// - And any future template loaded from activity_templates table
/// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/features/farm_management/application/workflows/dynamic_activity_engine.dart';
import 'package:famhub_app/features/farm_management/application/workflows/workflow_progress_engine.dart';
import 'package:famhub_app/features/farm_management/application/providers/activity_template_provider.dart';
import 'package:famhub_app/features/farm_management/config/workflow_templates.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/operational_services_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/dynamic_activity_form_renderer.dart';
import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/event_bus_provider.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

class DynamicActivityExecutionPage extends ConsumerStatefulWidget {
  final String templateId;

  const DynamicActivityExecutionPage({
    super.key,
    required this.templateId,
  });

  @override
  ConsumerState<DynamicActivityExecutionPage> createState() => _DynamicActivityExecutionPageState();
}

class _DynamicActivityExecutionPageState extends ConsumerState<DynamicActivityExecutionPage> {
  late WorkflowProgressEngine _workflowEngine;
  final Map<String, dynamic> _values = {};
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeWorkflow();
  }

  void _initializeWorkflow() {
    final template = PresetWorkflowTemplates.get(widget.templateId);
    if (template != null) {
      _workflowEngine = WorkflowProgressEngine(
        templateId: template.id,
        templateName: template.name,
        stages: template.stages,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = ref.watch(activityTemplateProvider(widget.templateId));
    final farmId = ref.watch(farmContextProvider).farmId;

    if (template == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Execution')),
        body: const Center(child: Text('Template not found')),
      );
    }

    final stage = _workflowEngine.state.currentStage;
    final progress = _workflowEngine.state.progress;

    return Scaffold(
      appBar: AppBar(
        title: Text(template.name),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
      ),
      body: farmId == null
          ? const Center(child: Text('Select a farm first'))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Progress Bar ──
                  if (template.stages.length > 1)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Step ${_workflowEngine.state.currentStageIndex + 1} of ${template.stages.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                          if (stage != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stage.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (stage.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                stage.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                  // ── Stage Indicator Dots ──
                  if (template.stages.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: template.stages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final isActive = idx == _workflowEngine.state.currentStageIndex;
                          final isPast = idx < _workflowEngine.state.currentStageIndex;
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isPast
                                    ? Theme.of(context).colorScheme.primary
                                    : isActive
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                        : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── Stage Description ──
                  if (template.stages.length <= 1)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        template.description ?? 'Complete the form below to record this activity',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),

                  // ── Dynamic Form Fields ──
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: DynamicActivityFormRenderer(
                        attributes: template.attributes,
                        values: _values,
                        onValueChanged: (key, value) {
                          setState(() => _values[key] = value);
                        },
                        onlyAttributes: stage?.requiredAttributes,
                      ),
                    ),
                  ),

                  // ── Action Buttons ──
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Back button
                        if (_workflowEngine.state.currentStageIndex > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _workflowEngine.previousStage());
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_workflowEngine.state.currentStageIndex > 0)
                          const SizedBox(width: 12),

                        // Next/Submit button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _handleNextOrSubmit(context, farmId, template),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLastStage(template)
                                        ? 'Complete & Record'
                                        : 'Continue',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _isLastStage(ActivityTemplate template) {
    return _workflowEngine.state.currentStageIndex >= template.stages.length - 1;
  }

  Future<void> _handleNextOrSubmit(
      BuildContext context, String farmId, ActivityTemplate template) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLastStage(template)) {
      // Final submission
      await _submitActivity(context, farmId, template);
    } else {
      // Advance to next stage
      setState(() {
        _workflowEngine.advanceStage(_values);
      });
    }
  }

  Future<void> _submitActivity(
      BuildContext context, String farmId, ActivityTemplate template) async {
    setState(() => _isSubmitting = true);
    try {
      // Advance to complete the workflow
      _workflowEngine.advanceStage(_values);

      // Build a structured notes summary from the collected values
      final notes = _values.entries
          .where((e) => e.value != null && e.value.toString().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');

      final repository = ref.read(farmRepositoryProvider);
      final stockEngine = ref.read(stockMutationEngineProvider);
      final kpiService = ref.read(kpiAutomationServiceProvider);
      final financialService = ref.read(financialRecordingServiceProvider);
      final eventBus = ref.read(eventBusProvider);

      // Step 1: Create the activity (with attribute values for persistence)
      final activity = ActivityModel(
        id: '',
        activityTypeId: template.id,
        performedAt: DateTime.now(),
        notes: '${template.name}\n$notes',
        assetId: null,
        planId: null,
        attributeValues: _values,
      );

      await repository.createActivity(farmId: farmId, activity: activity);
      if (!mounted) return;

      // ════════════════════════════════════════════════════════════
      // STEP 2 — STOCK MUTATION
      // ════════════════════════════════════════════════════════════
      // Based on activity category + template ID heuristics:
      //   Outflow (feeding, planting, spraying) → consume stock
      //   Inflow  (milking, harvesting, collection) → add stock
      // ════════════════════════════════════════════════════════════
      if (template.category == 'crops' || template.category == 'livestock') {
        final isOutflow = template.id.contains('feeding') ||
            template.id.contains('planting') ||
            template.id.contains('spraying') ||
            template.id.contains('fertilization');
        final isInflow = template.id.contains('milking') ||
            template.id.contains('harvesting') ||
            template.id.contains('collection');

        if (isOutflow) {
          final quantity = _values['feed_quantity'] ??
              _values['seed_rate'] ??
              _values['quantity'] ??
              0;
          if (quantity is num && quantity > 0) {
            final assets = await repository.getAssets(farmId: farmId);
            if (!mounted) return;
            final matchingAsset = assets.where((a) =>
                template.id.contains('feeding')
                    ? a.assetType == 'feed' || a.assetName.toLowerCase().contains('feed')
                    : a.assetType == 'input' || a.assetName.toLowerCase().contains('seed')
            ).firstOrNull;
            if (matchingAsset != null) {
              await stockEngine.consumeStock(
                farmId: farmId,
                assetId: matchingAsset.id,
                quantity: quantity.toDouble(),
                description: '${template.name}: stock consumption',
              );
            }
          }
        } else if (isInflow) {
          final quantity = _values['milk_volume'] ??
              _values['yield'] ??
              _values['quantity'] ??
              0;
          if (quantity is num && quantity > 0) {
            final assets = await repository.getAssets(farmId: farmId);
            if (!mounted) return;
            final matchingAsset = assets.where((a) =>
                a.assetType == 'production' ||
                (template.id.contains('milking') && a.assetName.toLowerCase().contains('milk')) ||
                (template.id.contains('harvest') && a.assetType == 'crop')
            ).firstOrNull;
            if (matchingAsset != null) {
              await stockEngine.addStock(
                farmId: farmId,
                assetId: matchingAsset.id,
                quantity: quantity.toDouble(),
                description: '${template.name}: production inflow',
              );
            }
          }
        }
      }

      // ════════════════════════════════════════════════════════════
      // STEP 3 — FINANCIAL RECORDING
      // ════════════════════════════════════════════════════════════
      final costPrice = _values['cost_price'];
      final salePrice = _values['sale_price'] ?? _values['income'];
      if (costPrice is num && costPrice > 0) {
        await financialService.recordExpense(
          farmId: farmId,
          amount: costPrice.toDouble(),
          description: 'Cost for ${template.name}',
        );
      }
      if (salePrice is num && salePrice > 0) {
        await financialService.recordIncome(
          farmId: farmId,
          amount: salePrice.toDouble(),
          description: 'Income from ${template.name}',
        );
      }

      // ════════════════════════════════════════════════════════════
      // STEP 4 — KPI AUTOMATION
      // ════════════════════════════════════════════════════════════
      await kpiService.updateProductionKpis(farmId: farmId);
      await kpiService.updateStockValueKpi(farmId: farmId);
      if (costPrice is num || salePrice is num) {
        await kpiService.updateFinancialKpis(farmId: farmId);
      }

      // ════════════════════════════════════════════════════════════
      // STEP 5 — TELEMETRY
      // ════════════════════════════════════════════════════════════
      eventBus.emit(WorkflowEvent.completed(
        workflowName: 'dynamic_activity',
        stepName: 'execute_${template.id}',
        payload: {
          'farm_id': farmId,
          'template_id': template.id,
          'template_name': template.name,
          'category': template.category,
        },
      ));

      // ════════════════════════════════════════════════════════════
      // STEP 6 — PROVIDER INVALIDATION
      // ════════════════════════════════════════════════════════════
      ref.invalidate(activitiesProvider);
      ref.invalidate(farmDashboardProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity recorded successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // Emit failure event for retry orchestration
      ref.read(eventBusProvider).emit(WorkflowEvent.failed(
        workflowName: 'dynamic_activity',
        stepName: 'execute_${template.id}',
        error: e.toString(),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record activity: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _submitActivity(context, farmId, template),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}