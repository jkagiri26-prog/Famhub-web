import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app/router/app_router_provider.dart';
import 'core/context/context_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔌 SUPABASE BOOTSTRAP (required for system.modules, feature_flags, etc.)
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    /// 🧠 Context engine boot (auth, session, environment, etc.)
    Future.microtask(() {
      ref.read(contextProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextProvider);

    /// 🚨 GLOBAL LOADING GATE
    if (ctx.isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    /// 🧭 ROUTER (module-aware navigation entry)
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,

      debugShowCheckedModeBanner: false,

      /// 🌐 OPTIONAL: future global theme hook
      themeMode: ctx.themeMode,
    );
  }
}