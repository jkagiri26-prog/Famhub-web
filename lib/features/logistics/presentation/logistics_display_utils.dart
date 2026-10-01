/// ============================================================
/// LOGISTICS DISPLAY UTILITIES
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/presentation/ = UI helpers
///
/// ✅ Responsibilities:
///   - Small pure formatters used by Logistics widgets.
///
/// ❌ Does NOT:
///   - Fetch data
///   - Hold state
/// ============================================================
library;

/// Short, locale-free timestamp: `12/03 14:05`.
/// Returns an em dash when the value is unknown.
String logisticsTimestamp(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

/// Shortens a uuid so dense lists stay readable on small screens.
String logisticsShortId(String id) {
  if (id.isEmpty) return '—';
  return id.length <= 8 ? id : id.substring(0, 8);
}
