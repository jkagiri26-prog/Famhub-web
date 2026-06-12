/// ============================================================
/// TABLET SHELL (RESPONSIVE SHELL VARIANT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Tablet-specific shell layout (600-1024px)
///   - Side navigation rail + content
///   - Child content rendering
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
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
            // ── Side Navigation Rail (Compact) ──
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
