/// ============================================================
/// CREATE BUSINESS PAGE (TRADER FIRST-USE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/presentation/pages/ = module pages
///
/// Shown when the Trader workspace is entered and the authoritative
/// active context has `businessProfileId == null`.
///
/// The user explicitly provides:
///   - Business name  → commerce.business_profiles.supplier_name
///   - Business type  → mapped commerce.business_profiles.entity_type
///                      (+ metadata.business_category)
///
/// The Entity already exists and is NEVER created/modified here. No
/// Business Profile is auto-created — the user must submit this form.
///
/// On success the authoritative context is re-read (existing
/// ContextController) and the Trader gate opens the dashboard.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/features/workspace_context/application/entity_context_refresh.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';

import '../../application/providers/business_profile_setup_provider.dart';
import '../../domain/enums/business_profile_category.dart';

class CreateBusinessPage extends ConsumerStatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  ConsumerState<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends ConsumerState<CreateBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  BusinessProfileCategory? _category;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final category = _category;
    if (!formValid || category == null) return;

    final entityId = ref.read(contextProvider).entityId;
    if (entityId == null || entityId.isEmpty) {
      _showMessage(
        'No active business entity was found. Please reopen the Trader '
        'workspace and try again.',
      );
      return;
    }

    final controller = ref.read(
      businessProfileSetupControllerProvider.notifier,
    );
    final ok = await controller.createBusiness(
      entityId: entityId,
      supplierName: _nameController.text,
      category: category,
      otherDescription: _descriptionController.text,
    );

    if (!mounted) return;

    if (!ok) {
      final message = ref
          .read(businessProfileSetupControllerProvider)
          .errorMessage;
      _showMessage(
        message ??
            'Could not create your business right now. Please try again.',
      );
      return;
    }

    // Link the newly created Business Profile to the canonical active
    // context through the EXISTING activation path
    // (users.activate_workspace_context → authoritative read → apply).
    // The gate then re-resolves `businessProfileId` and opens the dashboard.
    await _establishActiveContext(entityId);
    if (!mounted) return;
    if (!_contextHasBusinessProfile) {
      _showMessage(
        'Your business was saved, but we could not open the workspace '
        'automatically. Please reopen the Trader workspace.',
      );
    }
    refreshEntityScopedProviders(ref);
  }

  /// Whether the authoritative context currently carries a business profile.
  bool get _contextHasBusinessProfile =>
      (ref.read(contextProvider).businessProfileId ?? '').isNotEmpty;

  /// Establish the canonical active context for [entityId] after the
  /// Business Profile is created.
  ///
  /// Prefers the backend activation path (the same one the app-bar Entity
  /// switcher uses). If the authoritative context still has no
  /// `businessProfileId`, falls back to the canonical context re-read
  /// (`ContextController.init`). Nothing is fabricated.
  Future<void> _establishActiveContext(String entityId) async {
    final workspaceId = ref.read(activeWorkspaceProvider).workspaceId;
    final roleId = ref.read(contextProvider).roleId;

    var profileId = ref
        .read(businessProfileSetupControllerProvider)
        .createdBusinessProfileId;
    profileId ??= await _resolveContextBusinessProfileId(entityId);

    debugPrint(
      '[CreateBusiness] establish context '
      'workspace=$workspaceId entity=$entityId role=$roleId '
      'profile=$profileId',
    );

    if (workspaceId.isNotEmpty && roleId != null && roleId.isNotEmpty) {
      await ref
          .read(contextProvider.notifier)
          .activateContextRow(
            workspaceId: workspaceId,
            entityId: entityId,
            roleId: roleId,
            businessProfileId: profileId,
          );
      if ((ref.read(contextProvider).businessProfileId ?? '').isNotEmpty) {
        return;
      }
    }

    await ref.read(contextProvider.notifier).init();
  }

  /// Resolve the backend-reported `business_profile_id` for the active
  /// workspace/entity from the canonical available-contexts RPC.
  Future<String?> _resolveContextBusinessProfileId(String entityId) async {
    try {
      final workspaceId = ref.read(activeWorkspaceProvider).workspaceId;
      final contexts = await ref
          .read(authServiceProvider)
          .getAvailableWorkspaceContexts();
      for (final c in contexts) {
        if (c['workspace_id']?.toString() == workspaceId &&
            c['entity_id']?.toString() == entityId) {
          final id = c['business_profile_id']?.toString();
          if (id != null && id.isNotEmpty) return id;
        }
      }
    } catch (_) {}
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = ref
        .watch(businessProfileSetupControllerProvider)
        .isSubmitting;

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 24, bottom: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create your business',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set up your business to start using the Trader '
                      'workspace.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Business name ──
              const _FieldLabel(text: 'Business name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. James Trading',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Business name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Business type ──
              const _FieldLabel(text: 'Business type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<BusinessProfileCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select a business type',
                ),
                items: [
                  for (final category in BusinessProfileCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        setState(() => _category = value);
                        ref
                            .read(
                              businessProfileSetupControllerProvider.notifier,
                            )
                            .clearError();
                      },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a business type.';
                  }
                  return null;
                },
              ),

              // ── Category examples (guidance only, not selectable) ──
              if (_category != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Examples: ${_category!.examples}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Other description (optional) ──
              if (_category == BusinessProfileCategory.other) ...[
                const SizedBox(height: 20),
                const _FieldLabel(text: 'Tell us a little about your business'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isSubmitting,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create business'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}
