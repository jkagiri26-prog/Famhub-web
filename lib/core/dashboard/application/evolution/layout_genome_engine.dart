import '../../domain/models/dashboard_layout_binding_rule.dart';

class LayoutGenomeEngine {
  /// converts layout rules into “genetic structure”
  Map<String, dynamic> encode(List<DashboardLayoutBindingRule> rules) {
    return {
      for (final r in rules)
        r.layoutKey: {
          'priority': r.priority,
          'device': r.device,
          'role': r.role,
          'entity': r.entityId,
        }
    };
  }

  /// mutation point (future evolution step)
  List<String> mutateOrder(List<String> layouts) {
    final copy = List<String>.from(layouts);

    if (copy.length > 2) {
      copy.shuffle(); // simple mutation seed
    }

    return copy;
  }
}