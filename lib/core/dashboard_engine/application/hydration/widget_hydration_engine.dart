import '../../domain/models/widget_hydrated_state.dart';
import '../../application/state/widget_state_store.dart';
import '../../infrastructure/repositories/widget_hydration_repository.dart';

class WidgetHydrationEngine {
  WidgetHydrationEngine({
    required this.repository,
    required this.store,
  });

  final WidgetHydrationRepository repository;
  final WidgetStateStore store;

  /// ============================================================
  /// RESTORE ON APP START
  /// ============================================================
  Future<void> hydrate() async {
    final states = await repository.loadAll();

    for (final state in states) {
      store.upsert(
        WidgetStateModel(
          widgetId: state.widgetId,
          state: state.state,
          lastUpdated: state.updatedAt,
        ),
      );
    }
  }

  /// ============================================================
  /// PERSIST SINGLE WIDGET STATE
  /// ============================================================
  Future<void> persist(String widgetId) async {
    final state = store.get(widgetId);

    if (state == null) return;

    await repository.save(
      WidgetHydratedState(
        widgetId: widgetId,
        state: state.state,
        updatedAt: DateTime.now(),
      ),
    );
  }
}