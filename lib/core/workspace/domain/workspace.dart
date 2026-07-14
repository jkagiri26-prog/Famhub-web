/// ============================================================
/// WORKSPACE DOMAIN — BARREL FILE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/domain/ = workspace domain models
///
/// The workspace domain models are the single source of truth
/// for the user's active working session.
///
/// Every feature reads `activeWorkspaceProvider` instead of
/// managing tab state, navigation history, or layout independently.
///
/// ✅ Design Principles:
///   - Pure data — no evaluation logic
///   - Immutable — always use copyWith
///   - No Flutter dependencies
///   - Serializable for future persistence
/// ============================================================
library;

export 'workspace_data.dart';
export 'workspace_tab.dart';
export 'workspace_layout.dart';
export 'workspace_snapshot.dart';
