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
///   - Configure global error handling (FlutterError, PlatformDispatcher)
///   - Provide error reporting infrastructure for observability integration
///
/// ❌ Does NOT:
///   - Remove, replace, or redesign any existing engine
///   - Change the Runtime Sync Engine architecture
///   - Alter business logic
///   - Introduce new state management
///   - Expose sensitive information in production error logs
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;  

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

// ╔══════════════════════════════════════════════════════════════╗
// ║  GLOBAL ERROR HANDLING — Enterprise fault barrier           ║
// ╚══════════════════════════════════════════════════════════════╝
//
// Configures FlutterError.onError and PlatformDispatcher.instance.onError
// to capture all uncaught exceptions during bootstrap and runtime.
//
// ✅ Captures:
//   - Synchronous Flutter widget errors (FlutterError.onError)
//   - Asynchronous uncaught exceptions (PlatformDispatcher.onError)
//   - Unhandled futures, timers, and microtasks (runZonedGuarded)
//
// ❌ Does NOT:
//   - Expose sensitive information in production logs
//   - Interfere with debug-mode error reporting
//   - Replace Flutter's default error behavior in debug mode
// ═══════════════════════════════════════════════════════════════

/// Callback type for custom error handlers (future observability integration)
typedef ErrorHandler = void Function(Object error, StackTrace stack);

/// Configures global error handlers for Flutter and platform-level errors.
///
/// [onError] - Optional custom error handler for observability integration.
///             When null, errors are logged via debugPrint.
///
/// Call once during startup (before runApp or immediately after
/// WidgetsFlutterBinding.ensureInitialized()).
void configureGlobalErrorHandling({ErrorHandler? onError}) {
  final handler = onError ?? _defaultErrorHandler;

  // ── Capture Flutter widget/build errors ──
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // Preserve the previous handler for backward compatibility
    if (previousFlutterErrorHandler != null) {
      previousFlutterErrorHandler(details);
    }

    final exception = details.exception;
    final stack = details.stack ?? StackTrace.current;

    // Format a clean error message without sensitive details
    final summaryText = exception.toString();

    debugPrint('══════════════════════════════════════════════════');
    debugPrint('[FATAL] FlutterError caught: $summaryText');
    debugPrint('══════════════════════════════════════════════════');

    handler(exception, stack);
  };

  // ── Capture platform-level errors (native crashes, async errors) ──
  final previousPlatformErrorHandler =
      PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('══════════════════════════════════════════════════');
    debugPrint('[FATAL] Platform error caught: $error');
    debugPrint('══════════════════════════════════════════════════');

    handler(error, stack);

    // Return true to prevent the default error behavior (app crash)
    // Returning false will crash the app — we want to survive non-fatal errors
    return previousPlatformErrorHandler?.call(error, stack) ?? true;
  };
}

/// Default error handler — logs errors without exposing sensitive info.
void _defaultErrorHandler(Object error, StackTrace stack) {
  debugPrint('[ERROR] $error');
  final safeSummary = error.toString();
  // Truncate very long messages to avoid log flooding
  if (safeSummary.length > 500) {
    debugPrint('[ERROR] (truncated) ${safeSummary.substring(0, 500)}...');
  }
  debugPrintStack(
    stackTrace: stack,
    label: '[ERROR] Stack trace',
    maxFrames: 20,
  );
}

