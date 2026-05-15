import 'package:flutter/widgets.dart';

class _AppShellContext extends InheritedWidget {
  final bool isGuest;

  const _AppShellContext({
    required this.isGuest,
    required super.child,
  });

  static _AppShellContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppShellContext>();
  }

  @override
  bool updateShouldNotify(_AppShellContext oldWidget) {
    return isGuest != oldWidget.isGuest;
  }
}