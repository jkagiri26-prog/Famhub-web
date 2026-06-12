import 'package:famhub_app/core/dashboard_engine/domain/models/widget_state_model.dart';
import 'package:famhub_app/core/dashboard_engine/application/state/widget_state_store.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/repositories/widget_hydration_repository.dart';

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
      store.upsert(state);
    }
  }
  /// ============================================================
  /// PERSIST SINGLE WIDGET STATE
  /// ============================================================
  Future<void> persist(String widgetId) async {
    final state = store.get(widgetId);

    if (state == null) return;

    await repository.save(
      WidgetStateModel(
        widgetId: widgetId,
        state: state.state,
        lastUpdated: DateTime.now(),
      ),
    );
  }
}