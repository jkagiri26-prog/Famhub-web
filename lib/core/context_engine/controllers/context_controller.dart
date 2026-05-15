import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/entity_context.dart';
import '../services/context_storage_service.dart';
import '../services/context_sync_service.dart';

class ContextController extends StateNotifier<EntityContext> {
  final ContextStorageService storage;
  final ContextSyncService sync;

  ContextController(this.storage, this.sync)
      : super(EntityContext.empty);

  /// 🚀 INITIALIZE (App start)
  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    // 1. Load local
    final local = await storage.load();

    // 2. Apply local immediately (fast UI)
    state = state.copyWith(
      userId: local['userId'],
      role: local['role'],
      entityId: local['entityId'],
      isGuest: local['userId'] == null,
    );

    try {
      // 3. Sync with backend
      final remote = await sync.fetchUserContext();

      state = EntityContext(
        userId: remote['userId'],
        role: remote['role'],
        entityId: remote['entityId'],
        isGuest: false,
        isLoading: false,
      );

      // 4. Persist
      await storage.save(
        userId: remote['userId'],
        role: remote['role'],
        entityId: remote['entityId'],
      );
    } catch (e) {
      // Offline fallback
      state = state.copyWith(isLoading: false);
    }
  }

  /// 🔄 SWITCH ROLE
  Future<void> switchRole(String role) async {
    state = state.copyWith(role: role);

    await storage.save(
      userId: state.userId,
      role: role,
      entityId: state.entityId,
    );
  }

  /// 🔄 SWITCH ENTITY
  Future<void> switchEntity(String entityId) async {
    state = state.copyWith(entityId: entityId);

    await storage.save(
      userId: state.userId,
      role: state.role,
      entityId: entityId,
    );
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    await storage.clear();
    state = EntityContext.empty;
  }
}