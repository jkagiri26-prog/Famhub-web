import 'dashboard_zone_model.dart';

class ZoneDiff {
  const ZoneDiff({
    required this.zoneId,
    required this.previousWidgets,
    required this.nextWidgets,
  });

  final String zoneId;
  final List<dynamic> previousWidgets;
  final List<dynamic> nextWidgets;

  bool get hasChanges =>
      previousWidgets.length != nextWidgets.length ||
      !_listEquals(previousWidgets, nextWidgets);

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}