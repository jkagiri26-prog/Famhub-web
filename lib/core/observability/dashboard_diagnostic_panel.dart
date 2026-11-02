import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardDiagnosticLog {
  DashboardDiagnosticLog._();

  static const _maxEntries = 120;
  static const _maxEntryLength = 2400;
  static final ValueNotifier<List<String>> entries =
      ValueNotifier<List<String>>([]);
  static List<String> _latestEntries = [];
  static bool _notificationScheduled = false;

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
    _scheduleNotification();
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
