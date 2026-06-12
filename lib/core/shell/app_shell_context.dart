/// ============================================================
/// APP SHELL CONTEXT (INHERITED WIDGET FOR SHELL STATE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Provide shell context to child widgets
///   - Guest mode flag
///   - Shell-level state
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries
/// ============================================================

import 'package:flutter/widgets.dart';

class AppShellContext extends InheritedWidget {
  final bool isGuest;
  final bool isSystemDown;

  const AppShellContext({
    required this.isGuest,
    this.isSystemDown = false,
    required super.child,
  });

  static AppShellContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellContext>();
  }

  @override
  bool updateShouldNotify(AppShellContext oldWidget) {
    return isGuest != oldWidget.isGuest ||
        isSystemDown != oldWidget.isSystemDown;
  }
}