import '../../shared/widgets/cards/kpi_card.dart';
import '../../features/farm_management/presentation/widgets/activity_feed.dart';
import '../../shared/widgets/actions/quick_actions.dart';

class DashboardRegistry {
  static final Map<String, dynamic Function()> _widgets = {
    'kpi': () => const KPICard(),
    'activity': () => const ActivityFeed(),
    'actions': () => const QuickActions(),
  };

  /// Allows feature modules to register dashboard widgets by id.
  /// If a widget id isn't registered, the dashboard will render an empty box.
  static void register(String id, dynamic Function() builder) {
    _widgets[id] = builder;
  }

  static dynamic resolve(String id) {
    final builder = _widgets[id];
    if (builder == null) return const SizedBox.shrink();
    return builder();
  }
}