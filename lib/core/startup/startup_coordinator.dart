/// ============================================================
/// STARTUP COORDINATOR (v1)
/// ============================================================
///
/// 🧠 ROLE:
///   Orchestrate application startup with proper instrumentation,
///   error boundaries, timeouts, and deferred initialization.
///
/// ✅ RESPONSIBILITIES:
///   - Trace all startup stages with [BOOT] logging
///   - Catch and report every exception with full stack trace
///   - Validate environment configuration before Supabase init
///   - Separate CRITICAL (pre-runApp) from DEFERRED (post-frame) work
///   - Provide timeout safety for all async init calls
///
/// ❌ Does NOT:
///   - Remove, replace, or redesign any existing engine
///   - Change the Runtime Sync Engine architecture
///   - Alter business logic
///   - Introduce new state management
/// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Startup stages for tracing
enum BootStage {
  flutterBinding,
  supabaseInit,
  providerContainer,
  runtimeSyncEngineCreate,
  workflowOrchestrator,
  runApp,
  contextInit,
  runtimeSyncEngineInit,
  dashboardBootstrap,
}

/// Result of a single boot stage execution
class BootStageResult {
  final BootStage stage;
  final bool success;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration elapsed;

  const BootStageResult({
    required this.stage,
    required this.success,
    this.error,
    this.stackTrace,
    required this.elapsed,
  });

  void log() {
    if (success) {
      debugPrint('[BOOT] Completed ${stage.name} (${elapsed.inMilliseconds}ms)');
    } else {
      debugPrint('[BOOT] FAILED ${stage.name} (${elapsed.inMilliseconds}ms)');
      debugPrint('[BOOT] Error: $error');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace!, label: '[BOOT] Stack trace for ${stage.name}');
      }
    }
  }
}

/// Configuration sentinel — shown when env vars are missing
class _ConfigurationErrorWidget extends StatelessWidget {
  final String message;
  const _ConfigurationErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFFB71C1C),
      builder: (context, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFBDBDBD),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Provides a simple configuration error app as fallback
void runConfigurationErrorApp(String message) {
  runApp(_ConfigurationErrorWidget(message: message));
}

/// Run a boot stage with timing and error capture
Future<BootStageResult> runStage(
  BootStage stage,
  Future<void> Function() fn, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final sw = Stopwatch()..start();
  debugPrint('[BOOT] Stage ${stage.name}');

  try {
    await fn().timeout(timeout);
    sw.stop();
    final result = BootStageResult(
      stage: stage,
      success: true,
      elapsed: sw.elapsed,
    );
    result.log();
    return result;
  } catch (e, stack) {
    sw.stop();
    final result = BootStageResult(
      stage: stage,
      success: false,
      error: e,
      stackTrace: stack,
      elapsed: sw.elapsed,
    );
    result.log();
    return result;
  }
}

/// Validate that required environment variables are present
bool validateEnvironment() {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty) {
    debugPrint('[BOOT] CRITICAL: SUPABASE_URL is not set. '
        'Build with --dart-define=SUPABASE_URL=...');
    return false;
  }
  if (supabaseAnonKey.isEmpty) {
    debugPrint('[BOOT] CRITICAL: SUPABASE_ANON_KEY is not set. '
        'Build with --dart-define=SUPABASE_ANON_KEY=...');
    return false;
  }
  return true;
}
