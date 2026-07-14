/// ============================================================
/// NOTIFICATION SDK — Public facade for notification system
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose notification methods to feature modules
///   - Delegate to NotificationService and notification providers
///   - Never expose notification providers directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain UI
///   - Manage notification history directly
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/notification_service.dart';
import 'package:famhub_app/core/providers/notification_count_provider.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// NOTIFICATION SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final notif = ref.read(famhubNotificationSdkProvider);
///   notif.showSuccess('Operation completed');
///   notif.showError('Something went wrong');
///   final count = notif.badgeCount();
/// ============================================================
@PublicSdk()
class NotificationSdk {
  final Ref _ref;

  NotificationSdk(this._ref);

  NotificationService get _service => NotificationService.instance;

  /// Show a success notification
  @SdkMethod(version: '1.0.0')
  Future<void> showSuccess(String message) {
    return _service.show(
      title: 'Success',
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
    );
  }

  /// Show an error notification
  @SdkMethod(version: '1.0.0')
  Future<void> showError(String message) {
    return _service.show(
      title: 'Error',
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
    );
  }

  /// Show a warning notification
  @SdkMethod(version: '1.0.0')
  Future<void> showWarning(String message) {
    return _service.show(
      title: 'Warning',
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
    );
  }

  /// Show an info notification
  @SdkMethod(version: '1.0.0')
  Future<void> showInfo(String message) {
    return _service.show(
      title: 'Info',
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
    );
  }

  /// Show a custom notification
  @SdkMethod(version: '1.0.0')
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) {
    return _service.show(title: title, body: body, id: id, payload: payload);
  }

  /// Get the current badge count (unread notifications)
  @SdkMethod(version: '1.0.0')
  int badgeCount() =>
      _ref.read(unreadNotificationCountProvider);

  /// Refresh badge count
  @SdkMethod(version: '1.0.0')
  void refreshBadges() {
    // Re-read the provider to get latest count
    _ref.invalidate(unreadNotificationCountProvider);
  }

  /// Set the badge count directly
  @SdkMethod(version: '1.0.0')
  void setBadgeCount(int count) {
    _ref.read(unreadNotificationCountProvider.notifier).setCount(count);
  }

  /// Increment the badge count
  @SdkMethod(version: '1.0.0')
  void incrementBadge() {
    _ref.read(unreadNotificationCountProvider.notifier).increment();
  }

  /// Decrement the badge count
  @SdkMethod(version: '1.0.0')
  void decrementBadge() {
    _ref.read(unreadNotificationCountProvider.notifier).decrement();
  }

  /// Reset the badge count to zero
  @SdkMethod(version: '1.0.0')
  void resetBadge() {
    _ref.read(unreadNotificationCountProvider.notifier).reset();
  }
}

/// ============================================================
/// PROVIDER: NOTIFICATION SDK
/// ============================================================
@SdkProvider()
final famhubNotificationSdkProvider = Provider<NotificationSdk>((ref) {
  return NotificationSdk(ref);
});
