/// ============================================================
/// WORKSPACE STORAGE — DATA ACCESS CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/infrastructure/ = infrastructure layer
///
/// This repository defines the contract for loading and storing
/// workspace snapshots.
///
/// ✅ CURRENT STATE (Stage 3):
///   - In-memory implementation
///   - Stores workspaces in a Map
///   - Returns default workspace
///
/// ✅ FUTURE STATE:
///   - Supabase Workspace Storage
///   - Will persist snapshots to backend
///   - Will support organization-scoped workspaces
///
/// ✅ DESIGN PRINCIPLE:
///   The frontend should only consume the runtime,
///   never backend tables directly.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/workspace/domain/workspace_snapshot.dart';

/// ============================================================
/// WORKSPACE STORAGE
/// ============================================================
///
/// Abstract contract for workspace data access.
/// Enables clean future backend integration without
/// changing the domain or application layers.
/// ============================================================
abstract class WorkspaceStorage {
  /// Load the active workspace for the current user/organization.
  ///
  /// Returns the most recently saved workspace snapshot,
  /// or null if no saved workspace exists.
  Future<WorkspaceSnapshot?> loadActiveWorkspace();

  /// Load a specific workspace by ID.
  Future<WorkspaceSnapshot?> loadWorkspace(String workspaceId);

  /// Save a workspace snapshot for future restoration.
  Future<void> saveWorkspace(WorkspaceSnapshot snapshot);

  /// Delete a saved workspace.
  Future<void> deleteWorkspace(String workspaceId);

  /// List all saved workspace IDs for the current user.
  Future<List<String>> listWorkspaceIds();

  /// Load the last workspace snapshot for a given organization.
  ///
  /// Used when switching organizations to restore the
  /// organization's last workspace.
  Future<WorkspaceSnapshot?> loadOrganizationWorkspace(
    String organizationId,
  );

  /// Save a workspace snapshot associated with an organization.
  Future<void> saveOrganizationWorkspace(
    String organizationId,
    WorkspaceSnapshot snapshot,
  );

  /// Clear all saved workspaces (on logout).
  Future<void> clearAll();
}

/// ============================================================
/// IN-MEMORY WORKSPACE STORAGE (STAGE 3 STUB)
/// ============================================================
///
/// In-memory implementation for Stage 3 development.
/// Stores workspaces in a Map.
///
/// 🔄 Replace with real backend implementation when
///    the Supabase workspace storage is available.
/// ============================================================
class InMemoryWorkspaceStorage implements WorkspaceStorage {
  /// Currently active workspace ID
  String _activeWorkspaceId = 'workspace-default-001';

  /// Stored workspace snapshots by workspace ID
  final Map<String, WorkspaceSnapshot> _workspaces = {};

  /// Organization-scoped workspace snapshots
  final Map<String, WorkspaceSnapshot> _organizationWorkspaces = {};

  /// Default workspace snapshot
  WorkspaceSnapshot get _defaultSnapshot => WorkspaceSnapshot(
        workspaceId: _activeWorkspaceId,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      );

  @override
  Future<WorkspaceSnapshot?> loadActiveWorkspace() async {
    return _workspaces[_activeWorkspaceId] ?? _defaultSnapshot;
  }

  @override
  Future<WorkspaceSnapshot?> loadWorkspace(String workspaceId) async {
    return _workspaces[workspaceId];
  }

  @override
  Future<void> saveWorkspace(WorkspaceSnapshot snapshot) async {
    _workspaces[snapshot.workspaceId] = snapshot;
    _activeWorkspaceId = snapshot.workspaceId;
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    _workspaces.remove(workspaceId);
    if (_activeWorkspaceId == workspaceId) {
      _activeWorkspaceId = 'workspace-default-001';
    }
  }

  @override
  Future<List<String>> listWorkspaceIds() async {
    return _workspaces.keys.toList();
  }

  @override
  Future<WorkspaceSnapshot?> loadOrganizationWorkspace(
    String organizationId,
  ) async {
    return _organizationWorkspaces[organizationId];
  }

  @override
  Future<void> saveOrganizationWorkspace(
    String organizationId,
    WorkspaceSnapshot snapshot,
  ) async {
    _organizationWorkspaces[organizationId] = snapshot;
  }

  @override
  Future<void> clearAll() async {
    _workspaces.clear();
    _organizationWorkspaces.clear();
    _activeWorkspaceId = 'workspace-default-001';
  }

  // ── Test Helpers ──

  /// Add a custom workspace snapshot (for testing).
  void addWorkspace(WorkspaceSnapshot snapshot) {
    _workspaces[snapshot.workspaceId] = snapshot;
  }

  /// Add a custom organization workspace (for testing).
  void addOrganizationWorkspace(
    String organizationId,
    WorkspaceSnapshot snapshot,
  ) {
    _organizationWorkspaces[organizationId] = snapshot;
  }

  /// Get the count of stored workspaces.
  int get workspaceCount => _workspaces.length;

  /// Get the count of stored organization workspaces.
  int get organizationWorkspaceCount => _organizationWorkspaces.length;
}

/// ============================================================
/// REPOSITORY PROVIDER
/// ============================================================
///
/// Riverpod provider for workspace storage.
/// Swap this to the real backend implementation when ready.
/// ============================================================
final workspaceStorageProvider = Provider<WorkspaceStorage>((ref) {
  // TODO: Replace with real backend implementation (Supabase).
  return InMemoryWorkspaceStorage();
});
