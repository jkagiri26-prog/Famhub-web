/// ============================================================
/// WORKSPACE PROVIDER — ENGINE PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/workspace/application/ = application layer
///
/// Provides the WorkspaceEngine via Riverpod.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/workspace/application/workspace_engine.dart';
import 'package:famhub_app/core/workspace/infrastructure/workspace_storage.dart';

/// ============================================================
/// PROVIDER: WORKSPACE ENGINE
/// ============================================================
///
/// Provides the WorkspaceEngine backed by the storage layer.
/// ============================================================
final workspaceEngineProvider = Provider<WorkspaceEngine>((ref) {
  final storage = ref.watch(workspaceStorageProvider);
  return WorkspaceEngine(storage: storage);
});
