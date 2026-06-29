// ignore: dangling_library_doc_comments
/// ============================================================
/// TABLET SHELL (RESPONSIVE SHELL VARIANT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Tablet-specific shell layout (600-1024px)
///   - Compact sidebar navigation rail (backend-driven)
///   - Child content rendering
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
///   - Hardcode navigation items
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/side_nav.dart';

class TabletShell extends ConsumerWidget {
  final Widget child;

  const TabletShell({
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
            // ── Compact Side Navigation Rail ──
            const SideNav(isCollapsed: true),

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
