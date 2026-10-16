/// ============================================================
/// ASSISTANT CONTEXT ENVELOPE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/assistant/ = shell-level assistant seam
///
/// ✅ Responsibilities:
///   - Describe WHERE the user currently is (page/module), which
///     workspace is active, and which operating entity/role is active
///   - Serialize to the gateway's `context` channel as plain labels
///
/// ❌ Does NOT:
///   - Hold or resolve any farm/crop/livestock data (features own that)
///   - Carry raw identifiers (ids are never sent to the model)
///   - Act as authorization of any kind — this is descriptive context only
///
/// 🔒 PRIVACY RULE:
///   Only human-readable labels travel to the model. No workspace ids,
///   entity ids, role ids or profile ids are included, so a model cannot
///   be handed an identifier to act on. Every value originates from a
///   provider the signed-in user is already authorized to read.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

/// Snapshot of the user's current shell context at the moment the
/// assistant is opened (and on every rebuild while it is open).
@immutable
class AssistantContext {
  const AssistantContext({
    required this.route,
    this.moduleId,
    this.moduleName,
    this.workspaceName,
    this.workspaceType,
    this.contextMode,
    this.entityName,
  });

  /// Current router path, e.g. `/farm` or `/extension`.
  final String route;

  /// Resolved module id for [route]. Null when the route does not map to a
  /// known module — never guessed.
  final String? moduleId;

  /// Human-readable module name, e.g. `Farm Management`.
  final String? moduleName;

  /// Display name of the active workspace. Null while unknown.
  final String? workspaceName;

  /// Normalized workspace type (`farmer`, `trader`, …). Null while unknown.
  /// Used for launcher selection, not sent to the model.
  final String? workspaceType;

  /// Active operational role/mode from the entity context (e.g. `farmer`).
  final String? contextMode;

  /// Human-readable name of the active operating entity. Null when the
  /// authorized context list does not resolve one — never invented.
  final String? entityName;

  /// Labels shown in the assistant UI (order preserved, empties dropped).
  List<String> get visibleLabels => <String>[
        if (moduleName != null && moduleName!.isNotEmpty) moduleName!,
        if (workspaceName != null && workspaceName!.isNotEmpty)
          workspaceName!,
        if (entityName != null && entityName!.isNotEmpty) entityName!,
        if ((entityName == null || entityName!.isEmpty) &&
            contextMode != null &&
            contextMode!.isNotEmpty)
          contextMode!,
      ];

  /// Structured context forwarded to `ai-gateway` as the `context` block.
  ///
  /// Contains labels only. Omitted fields simply do not appear — the model
  /// is never told a page, workspace or entity exists unless it was really
  /// resolved from application state.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'current_page': route,
      if (moduleName != null && moduleName!.isNotEmpty)
        'current_module': moduleName!,
      if (workspaceName != null && workspaceName!.isNotEmpty)
        'active_workspace': workspaceName!,
      if (contextMode != null && contextMode!.isNotEmpty)
        'context_mode': contextMode!,
      if (entityName != null && entityName!.isNotEmpty)
        'active_entity': entityName!,
    };
  }

  @override
  String toString() =>
      'AssistantContext(route: $route, module: $moduleName, '
      'workspace: $workspaceName, mode: $contextMode, '
      'entity: $entityName)';
}
