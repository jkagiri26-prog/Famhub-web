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
  ///
  /// Loads persisted widget states from the backend and restores
  /// them into the local WidgetStateStore. This is purely for UI
  /// preference restoration (scroll position, filters, etc.).
  ///
  /// ⚠️ NON-CRITICAL: If the backend query fails (table missing,
  ///    network error, permission denied), this method silently
  ///    degrades. Widgets will initialize with defaults and
  ///    re-persist state on next user interaction.
  ///
  Future<void> hydrate() async {
    try {
      final states = await repository.loadAll();
      for (final state in states) {
        store.upsert(state);
      }
    } catch (e) {
      // Non-fatal — widget state restoration is optional.
      // Logging is handled by the caller (RuntimeSyncEngine).
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