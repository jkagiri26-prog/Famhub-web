import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'queue_models.dart';

class OfflineQueueService {
  static const _key = 'offline_queue';

  Future<List<QueueItem>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    return raw.map((e) {
      final json = jsonDecode(e);
      return QueueItem(
        id: json['id'],
        action: json['action'],
        payload: json['payload'],
        createdAt: DateTime.parse(json['createdAt']),
      );
    }).toList();
  }

  Future<void> add(QueueItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    list.add(jsonEncode({
      'id': item.id,
      'action': item.action,
      'payload': item.payload,
      'createdAt': item.createdAt.toIso8601String(),
    }));

    await prefs.setStringList(_key, list);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}