class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);

    // 🚨 SYSTEM-LEVEL GATE (module_control / maintenance / kill switch)
    if (ctx.isSystemDown) {
      return const Scaffold(
        body: Center(
          child: Text("System maintenance in progress"),
        ),
      );
    }

    // 🚨 GUEST ROUTING (unauthenticated users)
    if (ctx.isGuest) {
      return const GuestHomePage();
    }

    // 🧠 CORE LAYOUT ROUTING (device-level shell only)
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrappedChild = _wrapWithModuleContext(ref, child);

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

  /// 🔥 MODULE INJECTION LAYER (future-proof core hook)
  Widget _wrapWithModuleContext(WidgetRef ref, Widget child) {
    final ctx = ref.watch(contextProvider);

    /// 🚀 FUTURE SOURCES (DO NOT ENABLE YET)
    /// final modules = ref.watch(moduleProvider);
    /// final featureFlags = ref.watch(featureFlagProvider);

    /// 🧠 DESIGN RULE:
    /// AppShell MUST NOT decide business logic
    /// It only provides structural context

    return _AppShellContext(
      isGuest: ctx.isGuest,
      child: child,
    );
  }
}