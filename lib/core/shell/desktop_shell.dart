/// ============================================================
/// DESKTOP SHELL (RESPONSIVE SHELL VARIANT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Desktop-specific shell layout (> 1024px)
///   - Full side navigation
///   - Child content rendering
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/side_nav.dart';

class DesktopShell extends ConsumerWidget {
  final Widget child;

  const DesktopShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            // ── Side Navigation (Full Width) ──
            const SideNav(),
            
            // ── Vertical divider ──
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
            
            // ── Main Content ──
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
