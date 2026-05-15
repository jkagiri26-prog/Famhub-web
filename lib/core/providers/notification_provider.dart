import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppNotification {
  final String id;
  final String message;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationProvider with ChangeNotifier {
  final List<AppNotification> _notifications = [];
  
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Adds a notification and triggers a UI update
  void addNotification(String message) {
    final newNotification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, newNotification); // Latest first
    notifyListeners();
    
    // Optional: Persist to Hive if you want a notification history
    // ModuleRegistry.saveLocalData('notification_cache', newNotification.id, message);
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }
}