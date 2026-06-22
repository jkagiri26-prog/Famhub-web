// ignore: dangling_library_doc_comments
/// ============================================================
/// MOBILE SHELL (RESPONSIVE SHELL VARIANT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Mobile-specific shell layout (< 600px)
///   - Bottom navigation bar
///   - Child content rendering
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/bottom_nav.dart';

class MobileShell extends ConsumerWidget {
  final Widget child;

  const MobileShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: child,
      ),
      bottomNavigationBar: const BottomNav(),
    );
  }
}
