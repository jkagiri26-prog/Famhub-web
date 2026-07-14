/// ============================================================
/// WORKSPACE RUNTIME — BARREL FILE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/ = workspace runtime layer
///
/// The Workspace Runtime manages the user's active working session.
/// It does NOT contain business logic.
/// It only manages the runtime workspace.
///
/// ✅ Design Principles:
///   - Pure runtime — no business logic
///   - No Flutter dependencies
///   - No UI
///   - Immutable state models
///   - Serializable snapshots for future persistence
/// ============================================================
library;

export 'domain/workspace.dart';
export 'domain/workspace_tab.dart';
export 'domain/workspace_layout.dart';
export 'domain/workspace_snapshot.dart';
export 'application/workspace_engine.dart';
export 'application/workspace_provider.dart';
export 'application/active_workspace_provider.dart';
export 'composition/workspace_bridge.dart';
export 'infrastructure/workspace_storage.dart';
