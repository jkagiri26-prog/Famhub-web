/// ============================================================
/// ASSISTANT LAUNCHER REGISTRY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/assistant/ = shell-level assistant seam
///
/// ✅ PURPOSE:
///   Let the shell's existing AI Assistant button open a real assistant
///   WITHOUT the shell ever importing a feature module.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Same pattern as WidgetRegistry / ModulePageRegistry: a static
///     registry written to by features at bootstrap, read by core
///   - The shell stays domain-agnostic ("No feature module imports in shell")
///   - A later Trader / Marketplace / General assistant registers its own
///     launcher with zero further shell changes
///
/// ❌ Does NOT:
///   - Decide which assistant exists (features register their own)
///   - Create routes, tabs or navigation entries
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';

/// Opens an assistant for the current shell context.
///
/// [route] is the router path captured at tap time so the assistant knows
/// which module the user is looking at.
typedef AssistantLauncher = void Function(
  BuildContext context,
  WidgetRef ref,
  String route,
);

class AssistantLauncherRegistry {
  AssistantLauncherRegistry._();

  /// workspace type → launcher. Overwriting is allowed so repeated
  /// bootstrap calls (hot restart, Phase D + legacy bootstrap) are safe.
  static final Map<String, AssistantLauncher> _launchers =
      <String, AssistantLauncher>{};

  static void register(String workspaceType, AssistantLauncher launcher) {
    _launchers[workspaceType] = launcher;
  }

  static AssistantLauncher? resolve(String? workspaceType) {
    if (workspaceType == null || workspaceType.isEmpty) return null;
    return _launchers[workspaceType];
  }

  static bool isRegistered(String workspaceType) =>
      _launchers.containsKey(workspaceType);

  static List<String> get registeredWorkspaceTypes =>
      _launchers.keys.toList(growable: false);

  /// Testing / hot-reload helper.
  static void clear() => _launchers.clear();

  /// ============================================================
  /// OPEN — the single entry point used by the shell's AI Assistant button
  /// ============================================================
  ///
  /// Reads the current route and active workspace type, resolves a
  /// registered launcher, and hands off. When the active workspace has no
  /// assistant yet the user is told plainly instead of tapping into a
  /// silent no-op.
  /// ============================================================
  static void open(BuildContext context, WidgetRef ref) {
    final String route = GoRouterState.of(context).uri.toString();
    final AssistantLauncher? launcher =
        resolve(ref.read(activeWorkspaceTypeProvider));

    if (launcher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The FAMHUB AI assistant is not available for this workspace yet.',
          ),
        ),
      );
      return;
    }

    launcher(context, ref, route);
  }
}
