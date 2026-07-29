// ignore: dangling_library_doc_comments
/// ============================================================
/// DYNAMIC ACTIVITY EXECUTION PAGE
/// ============================================================
///
/// 🎯 PURPOSE:
///   Thin UI controller for dynamic activity workflows.
///   All business logic has been extracted to
///   DynamicActivityWorkflowService.
///
/// ✅ This widget ONLY:
///   - Renders the workflow UI (progress bar, form, buttons)
///   - Collects form values
///   - Validates the form
///   - Calls workflowService.executeWorkflow(...)
///   - Displays loading state
///   - Shows success/error SnackBars
///   - Invalidates providers
///   - Navigates back
///
/// ❌ Contains NO business logic:
///   - No activity creation
///   - No stock mutation logic
///   - No financial recording
///   - No KPI automation
///   - No event emission
///   - No rollback logic
/// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/features/farm_management/application/workflows/workflow_progress_engine.dart';
import 'package:famhub_app/features/farm_management/application/providers/activity_template_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/workflow_service_provider.dart';
import 'package:famhub_app/features/farm_management/application/services/dynamic_activity_workflow_service.dart';
import 'package:famhub_app/features/farm_management/config/workflow_templates.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_template.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/dynamic_activity_form_renderer.dart';

class DynamicActivityExecutionPage extends ConsumerStatefulWidget {
  final String templateId;

  const DynamicActivityExecutionPage({
    super.key,
    required this.templateId,
  });

  @override
  ConsumerState<DynamicActivityExecutionPage> createState() =>
      _DynamicActivityExecutionPageState();
}

class _DynamicActivityExecutionPageState
    extends ConsumerState<DynamicActivityExecutionPage> {
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
      return const ShellPageContent(
        title: 'Activity Execution',
        child: Center(child: Text('Template not found')),
      );
    }

    final stage = _workflowEngine.state.currentStage;
    final progress = _workflowEngine.state.progress;

    return ShellPageContent(
      title: template.name,
      scrollable: false,
      child: farmId == null
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stage.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                          final isActive =
                              idx == _workflowEngine.state.currentStageIndex;
                          final isPast =
                              idx < _workflowEngine.state.currentStageIndex;
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isPast
                                    ? Theme.of(context).colorScheme.primary
                                    : isActive
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.5)
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
                        template.description ??
                            'Complete the form below to record this activity',
                        style:
                            TextStyle(color: Colors.grey.shade600),
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
                                setState(
                                    () => _workflowEngine.previousStage());
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                                : () =>
                                    _handleNextOrSubmit(context, farmId, template),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
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
    return _workflowEngine.state.currentStageIndex >=
        template.stages.length - 1;
  }

  Future<void> _handleNextOrSubmit(
      BuildContext context, String farmId, ActivityTemplate template) async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLastStage(template)) {
      // Delegate to the workflow service — no business logic here
      await _executeWorkflow(context, farmId, template);
    } else {
      // Advance to next stage
      setState(() {
        _workflowEngine.advanceStage(_values);
      });
    }
  }

  Future<void> _executeWorkflow(
      BuildContext context, String farmId, ActivityTemplate template) async {
    // ── HIERARCHY VALIDATION ──
    // Activities MUST be linked to a valid Farm → Field → Crop/Livestock path.
    // The user must select all hierarchy levels before recording an activity.
    final hierarchy = ref.read(hierarchyProvider);
    if (!hierarchy.hasFullSelection) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a Field and Crop/Livestock before recording an activity.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Advance to complete the workflow
      _workflowEngine.advanceStage(_values);

      // ── DELEGATE ALL BUSINESS LOGIC TO SERVICE ──
      final workflowService = ref.read(dynamicActivityWorkflowServiceProvider);
      final result = await workflowService.executeWorkflow(
        farmId: farmId,
        fieldId: hierarchy.fieldId!,
        cropOrLivestockId: hierarchy.cropOrLivestockId!,
        cropOrLivestockType: hierarchy.cropOrLivestockType!,
        template: template,
        formValues: _values,
      );

      if (result.errorMessage != null) {
        throw Exception(result.errorMessage);
      }

      // The activity ID was generated by the backend
      final backendActivityId = result.activityId;
      // ignore: avoid_print
      debugPrint('Activity created with backend ID: $backendActivityId');

      // ── PROVIDER INVALIDATION ──
      ref.invalidate(activitiesProvider);
      ref.invalidate(farmDashboardProvider);
      ref.invalidate(farmLifecycleProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity recorded successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record activity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}