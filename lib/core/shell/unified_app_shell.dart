import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/system_state_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemState = ref.watch(systemStateProvider);

    // ============================================================
    // SYSTEM DOWN GATE (GLOBAL BLOCKER)
    // ============================================================
    if (systemState.isSystemDown) {
      return const Scaffold(
        body: Center(
          child: Text('System maintenance in progress'),
        ),
      );
    }

    // ============================================================
    // RESPONSIVE SHELL WRAPPER
    // ============================================================
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrappedChild = _AppShellContext(child: child);

        if (constraints.maxWidth < 600) {
          return MobileShell(child: wrappedChild);
        } else if (constraints.maxWidth < 1024) {
          return TabletShell(child: wrappedChild);
        } else {
          return DesktopShell(child: wrappedChild);
        }
      },
    );
  }
}

class _AppShellContext extends StatelessWidget {
  final Widget child;

  const _AppShellContext({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}