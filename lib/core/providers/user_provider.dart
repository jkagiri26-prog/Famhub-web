import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  factory AppUser.anonymous() => const AppUser(displayName: 'Guest');

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'role': role,
      };
}

/// ============================================================
/// USER PROVIDER
/// ============================================================
final userProvider = Provider<AppUser>((ref) {
  // TODO: Connect to actual auth service when available
  return AppUser.anonymous();
});
