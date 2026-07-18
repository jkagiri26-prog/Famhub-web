
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_provider.dart';

/// ============================================================
/// USER MODEL
/// ============================================================
class AppUser {
  final String displayName;
  final String? email;
  final String? role;

  const AppUser({
    this.displayName = 'User',
    this.email,
    this.role,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'role': role,
      };

  /// Create from an AppSession
  factory AppUser.fromSession(AppSession session) {
    if (session is AuthenticatedSession) {
      return AppUser(
        displayName: session.displayName,
        email: session.userId, // userId as fallback display identifier
        role: session.selectedRoles.isNotEmpty
            ? session.selectedRoles.first
            : null,
      );
    }
    return const AppUser(displayName: 'Visitor');
  }
}

/// ============================================================
/// USER PROVIDER
/// ============================================================
final userProvider = Provider<AppUser>((ref) {
  final session = ref.watch(sessionProvider);
  return AppUser.fromSession(session);
});
