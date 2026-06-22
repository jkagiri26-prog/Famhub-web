import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// =======================================================
/// FAMHUB NOTIFICATION SERVICE
/// =======================================================
///
/// RESPONSIBILITY:
/// - Local notifications (offline-first alerts)
/// - User-facing alerts (marketplace, advisory, system)
/// - Tap handling hooks (navigation layer later)
///
/// RULES:
/// - NO business logic
/// - NO feature decisions
/// - ONLY notification delivery + initialization
///
/// =======================================================

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// =======================================================
  /// INIT
  /// =======================================================

  Future<void> init() async {
    if (_initialized) return;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

            await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) {
        _handleTap(response);
      },
    );

    _initialized = true;
  }

  /// =======================================================
  /// SHOW NOTIFICATION
  /// =======================================================

  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'famhub_channel',
      'FAMHUB Notifications',
      channelDescription:
          'General notifications for FAMHUB system alerts',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

        await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// =======================================================
  /// SCHEDULED EXTENSION HOOK (future use)
  /// =======================================================

    Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Placeholder for future farming reminders,
    // advisory alerts, and marketplace notifications.
    // When implementing, use:
    // await _plugin.schedule(
    //   id: id,
    //   title: title,
    //   body: body,
    //   scheduledDate: scheduledTime,
    //   notificationDetails: details,
    // );
  }

  /// =======================================================
  /// TAP HANDLER
  /// =======================================================

  void _handleTap(NotificationResponse response) {
    final payload = response.payload;

    // DO NOT implement navigation here.
    // This will be handled by app router / dashboard engine later.

    if (payload == null) return;
  }

  /// =======================================================
  /// CANCEL
  /// =======================================================

  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
