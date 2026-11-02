import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardDiagnosticLog {
  DashboardDiagnosticLog._();

  static const _maxEntries = 120;
  static const _maxEntryLength = 2400;
  static const _storageKey = 'temporary_dashboard_diagnostics_v1';
  static final ValueNotifier<List<String>> entries =
      ValueNotifier<List<String>>([]);
  static final ValueNotifier<String?> persistenceError =
      ValueNotifier<String?>(null);
  static String? diagnosticScope;
  static List<String> _latestEntries = [];
  static bool _notificationScheduled = false;
  static bool _persistenceScheduled = false;
  static bool _discardPersistedEntries = false;
  static SharedPreferences? _preferences;
  static Future<void>? _initializeFuture;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() =>
      _initializeFuture ??= _loadPersistedEntries();

  static void setDiagnosticScope(String? scope) {
    diagnosticScope = scope;
  }

  static Future<void> _loadPersistedEntries() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _preferences = preferences;
      final encoded = preferences.getString(_storageKey);
      if (encoded != null && !_discardPersistedEntries) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          final persisted = decoded.whereType<String>().toList();
          _latestEntries = [
            ...persisted,
            ..._latestEntries,
          ];
          if (_latestEntries.length > _maxEntries) {
            _latestEntries.removeRange(
              0,
              _latestEntries.length - _maxEntries,
            );
          }
        }
      }
      _discardPersistedEntries = false;
      persistenceError.value = null;
      _scheduleNotification();
    } catch (error) {
      persistenceError.value = error.runtimeType.toString();
    }
  }

  static void record(
    String message, {
    StackTrace? stackTrace,
    int maxFrames = 12,
  }) {
    final timestamped = '[${DateTime.now().toIso8601String()}] $message';
    final stackLines = stackTrace
        ?.toString()
        .split('\n')
        .take(maxFrames)
        .join('\n');
    final combined = stackLines == null
        ? timestamped
        : '$timestamped\n$stackLines';
    final bounded = combined.length <= _maxEntryLength
        ? combined
        : '${combined.substring(0, _maxEntryLength)}…';
    final next = [..._latestEntries, bounded];
    if (next.length > _maxEntries) {
      next.removeRange(0, next.length - _maxEntries);
    }
    _latestEntries = next;
    _scheduleNotification();
    _schedulePersistence();

    debugPrint(message);
    if (stackTrace != null) {
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[$maxFrames diagnostic stack frames]',
        maxFrames: maxFrames,
      );
    }
  }

  static void clear() {
    _latestEntries = [];
    _discardPersistedEntries = true;
    _scheduleNotification();
    _schedulePersistence();
  }

  static void _schedulePersistence() {
    if (_persistenceScheduled) return;
    _persistenceScheduled = true;
    unawaited(Future<void>.delayed(const Duration(milliseconds: 250), () async {
      _persistenceScheduled = false;
      await _persistEntries();
    }));
  }

  static Future<void> _persistEntries() async {
    await initialize();
    _discardPersistedEntries = false;
    final preferences = _preferences;
    if (preferences == null) return;
    final encoded = jsonEncode(_latestEntries);
    _writeQueue = _writeQueue.then((_) async {
      try {
        await preferences.setString(_storageKey, encoded);
        persistenceError.value = null;
      } catch (error) {
        persistenceError.value = error.runtimeType.toString();
      }
    });
    await _writeQueue;
  }

  static void _scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      entries.value = List.unmodifiable(_latestEntries);
    });
  }

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DashboardDiagnosticSheet(),
    );
  }
}

class _DashboardDiagnosticSheet extends StatelessWidget {
  const _DashboardDiagnosticSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Temporary diagnostics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy diagnostics',
                  onPressed: () => _copyDiagnostics(context),
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: 'Clear diagnostics',
                  onPressed: DashboardDiagnosticLog.clear,
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ValueListenableBuilder<String?>(
            valueListenable: DashboardDiagnosticLog.persistenceError,
            builder: (context, error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                error == null
                    ? 'Diagnostics are saved on this device until cleared.'
                    : 'Could not save diagnostics across reloads ($error).',
                style: TextStyle(
                  color: error == null ? colors.onSurfaceVariant : colors.error,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: DashboardDiagnosticLog.entries,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No diagnostic events captured yet.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SelectableText(
                      entries[entries.length - index - 1],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'IDs are abbreviated. Review copied output and redact personal details before sharing.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyDiagnostics(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final output = DashboardDiagnosticLog.entries.value.reversed.join('\n\n');
    if (output.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No diagnostic output to copy.')),
      );
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: output));
      messenger.showSnackBar(
        const SnackBar(content: Text('Diagnostics copied to clipboard.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not access clipboard; select the log text to copy.'),
        ),
      );
    }
  }
}
