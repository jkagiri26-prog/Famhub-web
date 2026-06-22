import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_storage_service_provider.dart';
import 'package:famhub_app/core/context_engine/services/context_storage_service.dart';
import 'package:famhub_app/core/context_engine/services/context_sync_service.dart';

class ContextController extends Notifier<EntityContext> {
  late final ContextStorageService storage;
  late final ContextSyncService sync;

  @override
  EntityContext build() {
    storage = ref.read(contextStorageServiceProvider);
    sync = ref.read(contextSyncServiceProvider);

    return const EntityContext();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    final local = await storage.load();

    state = state.copyWith(
      userId: local['userId'],
      role: local['role'],
      entityId: local['entityId'],
      tier: local['tier'] ?? 'free',
      isGuest: local['userId'] == null,
      isLoading: true,
    );

    try {
      final remote = await sync.fetchUserContext();

      state = EntityContext(
        userId: remote['userId'],
        role: remote['role'],
        entityId: remote['entityId'],
        tier: remote['tier'] ?? 'free',
        isGuest: false,
        isLoading: false,
      );

      await storage.save(
        userId: remote['userId'],
        role: remote['role'],
        entityId: remote['entityId'],
        tier: remote['tier'] ?? 'free',
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> switchRole(String role) async {
    state = state.copyWith(role: role);

    await storage.save(
      userId: state.userId,
      role: role,
      entityId: state.entityId,
      tier: state.tier,
    );
  }

  Future<void> switchEntity(String entityId) async {
    state = state.copyWith(entityId: entityId);

    await storage.save(
      userId: state.userId,
      role: state.role,
      entityId: entityId,
      tier: state.tier,
    );
  }

  Future<void> logout() async {
    await storage.clear();
    state = EntityContext.empty;
  }
}