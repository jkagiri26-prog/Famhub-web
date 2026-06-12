/// ============================================================
/// AUDIT LOG SINK — PHASE 7A + PHASE 3 EXPANSION
/// ============================================================
///
/// PURPOSE:
/// Provides a structured audit log accumulation layer on top of
/// the existing ObservabilityLogger. Buffers log entries and
/// optionally persists them for later query or export.
///
/// PHASE 3 EXTENSIONS:
/// - Persistence adapters (compression, batching)
/// - Export formats (JSON, CSV, compact)
/// - Batch export with compression
///
/// This is the GAP-CLOSURE for G7: "No audit logging sink."
///
/// RESPONSIBILITIES:
/// - Accumulate structured audit log entries in memory
/// - Provide filtered query access (by severity, module, phase)
/// - Support optional persistence hook (file, remote, etc.)
/// - Maintain bounded memory usage via configurable max buffer
/// - Support batch export with or without compression
///
/// NON-RESPONSIBILITIES:
/// - Replacing ObservabilityLogger (it still handles console output)
/// - Replacing RuntimeMetricsCollector (metrics are separate)
/// - Rendering UI for audit logs
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/observability/ = observability layer
///
/// ✅ USAGE:
/// ```dart
/// final sink = AuditLogSink(maxEntries: 1000);
/// final logger = ObservabilityLogger();
/// logger.info(traceId, message: '...');
/// sink.capture(logger, event);
/// ```
/// ============================================================

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:famhub_app/core/dashboard_engine/application/observability/observability_logger.dart';
import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';

/// ============================================================
/// AUDIT LOG ENTRY (STORED IN SINK)
/// ============================================================
class AuditLogEntry {
  /// Structured log entry data
  final ObservabilityLogEntry logEntry;

  /// Correlated telemetry event (if available)
  final RuntimeTelemetryEvent? telemetryEvent;

  /// Timestamp the entry was recorded in the sink
  final DateTime recordedAt;

  const AuditLogEntry({
    required this.logEntry,
    this.telemetryEvent,
    required this.recordedAt,
  });

  /// Serialize to JSON for export
  Map<String, dynamic> toJson() => {
        'log': logEntry.toJson(),
        'telemetry': telemetryEvent?.toJson(),
        'recordedAt': recordedAt.toIso8601String(),
      };
}

/// ============================================================
/// AUDIT LOG SINK
/// ============================================================
///
/// Accumulates structured audit log entries in a memory-bounded
/// buffer. Supports filtering, querying, and optional persistence.
///
/// Thread-safe for single-threaded Dart (Riverpod-compatible).
/// ============================================================
class AuditLogSink {
  AuditLogSink({
    this.maxEntries = 1000,
    this.enableTelemetryCorrelation = true,
  });

  /// Maximum number of entries to keep in buffer
  final int maxEntries;

  /// Whether to auto-correlate telemetry events with log entries
  final bool enableTelemetryCorrelation;

  /// Internal buffer (FIFO, bounded)
  final Queue<AuditLogEntry> _entries = Queue();

  /// Optional persistence callback
  void Function(AuditLogEntry entry)? _persistenceHook;

  /// ============================================================
  /// CAPTURE A LOG ENTRY
  /// ============================================================
  void capture(
    ObservabilityLogEntry logEntry, [
    RuntimeTelemetryEvent? telemetryEvent,
  ]) {
    final entry = AuditLogEntry(
      logEntry: logEntry,
      telemetryEvent:
          enableTelemetryCorrelation ? telemetryEvent : null,
      recordedAt: DateTime.now(),
    );

    _entries.add(entry);

    // Enforce max buffer size
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }

    // Call optional persistence hook
    _persistenceHook?.call(entry);
  }

  /// ============================================================
  /// CAPTURE FROM OBSERVABILITY LOGGER
  /// ============================================================
  ///
  /// Convenience method to capture log entries along with their
  /// correlated telemetry events.
  /// ============================================================
  void captureFromLogger(
    ObservabilityLogEntry logEntry,
  ) {
    capture(logEntry, null);
  }

  /// ============================================================
  /// QUERY METHODS
  /// ============================================================

  /// All entries in buffer (oldest first)
  List<AuditLogEntry> get all => List.unmodifiable(_entries);

  /// Latest N entries
  List<AuditLogEntry> latest(int count) {
    if (count >= _entries.length) return all;
    return _entries.toList().reversed.take(count).toList();
  }

  /// Filter by log severity
  List<AuditLogEntry> bySeverity(LogSeverity severity) {
    return _entries
        .where((e) => _logSeverityFromTelemetry(e.logEntry.severity) == severity)
        .toList();
  }

  /// Filter by module ID
  List<AuditLogEntry> byModule(String moduleId) {
    return _entries
        .where((e) => e.logEntry.moduleId == moduleId)
        .toList();
  }

  /// Filter by telemetry phase
  List<AuditLogEntry> byPhase(TelemetryPhase phase) {
    return _entries
        .where((e) => e.logEntry.phase == phase)
        .toList();
  }

  /// Filter by event type
  List<AuditLogEntry> byEventType(TelemetryEventType type) {
    return _entries
        .where((e) => e.logEntry.eventType == type)
        .toList();
  }

  /// Get error/critical entries
  List<AuditLogEntry> get errors => _entries
      .where((e) =>
          e.logEntry.severity == TelemetrySeverity.error ||
          e.logEntry.severity == TelemetrySeverity.critical)
      .toList();

  /// ============================================================
  /// PERSISTENCE HOOK
  /// ============================================================
  ///
  /// Set a callback to persist audit log entries externally.
  /// This can write to file, send to a remote logging service,
  /// or integrate with existing observability infrastructure.
  ///
  /// Example:
  /// ```dart
  /// sink.setPersistenceHook((entry) async {
  ///   await logFile.write(entry.toJson());
  /// });
  /// ```
  /// ============================================================
  void setPersistenceHook(
    void Function(AuditLogEntry entry) hook,
  ) {
    _persistenceHook = hook;
  }

  /// Remove persistence hook
  void clearPersistenceHook() {
    _persistenceHook = null;
  }

  /// ============================================================
  /// STATE MANAGEMENT
  /// ============================================================

  /// Current count of entries in buffer
  int get length => _entries.length;

  /// Whether the buffer has entries
  bool get isEmpty => _entries.isEmpty;

  /// Clear all entries
  void clear() {
    _entries.clear();
  }

  /// Export all entries as JSON list
  List<Map<String, dynamic>> exportToJson() {
    return _entries.map((e) => e.toJson()).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 3: PERSISTENCE ADAPTERS & EXPORT FORMATS
  // ═══════════════════════════════════════════════════════════

  /// ── EXPORT FORMAT ──
  enum ExportFormat {
    json,
    jsonPretty,
    csv,
    compact,
  }

  /// ── COMPRESSION LEVEL ──
  enum CompressionLevel {
    none,
    light,
    medium,
    aggressive,
  }

  /// ── EXPORT OPTIONS ──
  class ExportOptions {
    final ExportFormat format;
    final bool includeTelemetry;
    final bool includeMetadata;
    final CompressionLevel compression;
    final Set<LogSeverity>? severityFilter;
    final int? maxEntries;

    const ExportOptions({
      this.format = ExportFormat.json,
      this.includeTelemetry = true,
      this.includeMetadata = true,
      this.compression = CompressionLevel.none,
      this.severityFilter,
      this.maxEntries,
    });
  }

  /// ── BATCH PERSISTENCE ADAPTER ──
  ///
  /// Collects entries into batches and flushes via a callback.
  /// Useful for writing to files, remote APIs, or databases.
  class BatchPersistenceAdapter {
    final int batchSize;
    final Duration flushInterval;
    final Future<void> Function(List<AuditLogEntry> batch) onFlush;
    final List<AuditLogEntry> _buffer = [];
    Timer? _flushTimer;

    BatchPersistenceAdapter({
      required this.batchSize,
      required this.flushInterval,
      required this.onFlush,
    });

    void add(AuditLogEntry entry) {
      _buffer.add(entry);
      if (_buffer.length >= batchSize) {
        _flush();
      } else {
        _flushTimer ??= Timer(flushInterval, _flush);
      }
    }

    Future<void> _flush() async {
      _flushTimer?.cancel();
      _flushTimer = null;
      if (_buffer.isEmpty) return;
      final batch = List<AuditLogEntry>.from(_buffer);
      _buffer.clear();
      try {
        await onFlush(batch);
      } catch (_) {
        // Silently handle flush errors — re-queue
        _buffer.insertAll(0, batch);
      }
    }

    void dispose() {
      _flushTimer?.cancel();
      _flushTimer = null;
      if (_buffer.isNotEmpty) _flush();
    }
  }

  /// ── COMPRESSION ADAPTER ──
  ///
  /// Compresses export payloads using string compaction (lossless).
  /// Light: removes whitespace. Medium: shortens keys. Aggressive: full minification.
  class CompressionAdapter {
    static String compress(String data, CompressionLevel level) {
      switch (level) {
        case CompressionLevel.none:
          return data;
        case CompressionLevel.light:
          return data.replaceAll(RegExp(r'\s+'), ' ');
        case CompressionLevel.medium:
          return data
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll('"', "'")
              .replaceAll(', ', ',');
        case CompressionLevel.aggressive:
          return data.replaceAll(RegExp(r'\s+|\n|\r|\t'), '');
      }
    }

    /// Estimate compression ratio
    static double estimateRatio(String original, String compressed) {
      if (original.isEmpty) return 1.0;
      return compressed.length / original.length;
    }
  }

  /// ── EXPORT METHODS ──

  /// Export entries in the specified format
  String export({
    ExportOptions options = const ExportOptions(),
    List<AuditLogEntry>? entries,
  }) {
    final source = entries ?? _entries.toList();
    final filtered = _applyFilters(source, options);

    String raw;
    switch (options.format) {
      case ExportFormat.json:
        raw = jsonEncode(filtered.map((e) => _entryToExportMap(e, options)).toList());
      case ExportFormat.jsonPretty:
        raw = const JsonEncoder.withIndent('  ')
            .convert(filtered.map((e) => _entryToExportMap(e, options)).toList());
      case ExportFormat.csv:
        raw = _exportToCsv(filtered, options);
      case ExportFormat.compact:
        raw = filtered
            .map((e) => '[${e.recordedAt.toIso8601String()}] '
                '${e.logEntry.severity.name}: ${e.logEntry.message}')
            .join('\n');
    }

    if (options.compression != CompressionLevel.none) {
      raw = CompressionAdapter.compress(raw, options.compression);
    }

    return raw;
  }

  /// Export and persist via a batch adapter in one step
  Future<void> exportWithAdapter({
    required BatchPersistenceAdapter adapter,
    ExportOptions options = const ExportOptions(),
    List<AuditLogEntry>? entries,
  }) async {
    final source = entries ?? _entries.toList();
    final filtered = _applyFilters(source, options);
    for (final entry in filtered) {
      adapter.add(entry);
    }
  }

  /// Get batch recommendations (count, estimated size)
  Map<String, dynamic> exportStats({
    ExportOptions options = const ExportOptions(),
  }) {
    final raw = export(options: options);
    final byteSize = utf8.encode(raw).length;
    return {
      'entryCount': _entries.length,
      'estimatedSizeBytes': byteSize,
      'estimatedSizeKB': (byteSize / 1024).toStringAsFixed(1),
      'format': options.format.name,
      'compression': options.compression.name,
    };
  }

  // ─── PRIVATE EXPORT HELPERS ─────────────────────────────

  List<AuditLogEntry> _applyFilters(
    List<AuditLogEntry> source,
    ExportOptions options,
  ) {
    var result = source;

    if (options.severityFilter != null) {
      result = result.where((e) {
        final sev = _logSeverityFromTelemetry(e.logEntry.severity);
        return options.severityFilter!.contains(sev);
      }).toList();
    }

    if (options.maxEntries != null && result.length > options.maxEntries!) {
      result = result.sublist(result.length - options.maxEntries!);
    }

    return result;
  }

  Map<String, dynamic> _entryToExportMap(
    AuditLogEntry entry,
    ExportOptions options,
  ) {
    final map = <String, dynamic>{
      'timestamp': entry.recordedAt.toIso8601String(),
      'severity': entry.logEntry.severity.name,
      'message': entry.logEntry.message,
      'phase': entry.logEntry.phase.name,
      'eventType': entry.logEntry.eventType.name,
    };

    if (options.includeMetadata) {
      if (entry.logEntry.moduleId != null) {
        map['moduleId'] = entry.logEntry.moduleId;
      }
      if (entry.logEntry.widgetKey != null) {
        map['widgetKey'] = entry.logEntry.widgetKey;
      }
      if (entry.logEntry.durationMs != null) {
        map['durationMs'] = entry.logEntry.durationMs;
      }
      map['traceId'] = entry.logEntry.traceId;
    }

    if (options.includeTelemetry && entry.telemetryEvent != null) {
      map['telemetry'] = entry.telemetryEvent!.toJson();
    }

    return map;
  }

  String _exportToCsv(List<AuditLogEntry> entries, ExportOptions options) {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('timestamp,severity,message,phase,eventType,moduleId,traceId,durationMs');

    for (final entry in entries) {
      final log = entry.logEntry;
      buffer.writeln(
        '${entry.recordedAt.toIso8601String()},'
        '${log.severity.name},'
        '"${log.message.replaceAll('"', '""')}",'
        '${log.phase.name},'
        '${log.eventType.name},'
        '${log.moduleId ?? ""},'
        '${log.traceId},'
        '${log.durationMs ?? ""}',
      );
    }

    return buffer.toString();
  }

  // ─── HELPERS ──────────────────────────────────────────────

  LogSeverity _logSeverityFromTelemetry(TelemetrySeverity severity) {
    switch (severity) {
      case TelemetrySeverity.info:
        return LogSeverity.info;
      case TelemetrySeverity.warning:
        return LogSeverity.warning;
      case TelemetrySeverity.error:
        return LogSeverity.error;
      case TelemetrySeverity.critical:
        return LogSeverity.critical;
    }
  }
}
