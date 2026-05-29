import 'dart:async';
import 'package:flutter/scheduler.dart';

typedef FrameTask = Future<void> Function();

class DashboardFrameScheduler {
  DashboardFrameScheduler({
    this.maxTasksPerFrame = 16,
    this.maxQueueSize = 200,
    this.onBacklogWarning,
    this.onMetricsUpdate,
    this.onDroppedTask,
  });

  final int maxTasksPerFrame;
  final int maxQueueSize;

  final void Function(int backlog)? onBacklogWarning;
  final void Function(int backlog, int queueSize)? onMetricsUpdate;

  /// NEW: observability for dropped tasks
  final void Function()? onDroppedTask;

  final List<FrameTask> _queue = [];

  bool _scheduled = false;

  int _backlog = 0;
  int _droppedTasks = 0;

  // ============================================================
  // TASK SCHEDULING
  // ============================================================

  void schedule(FrameTask task) {
    if (_queue.length >= maxQueueSize) {
      _droppedTasks++;
      onDroppedTask?.call();
      return;
    }

    _queue.add(task);

    _updateMetrics();

    if (_queue.length > maxTasksPerFrame * 2) {
      onBacklogWarning?.call(_queue.length);
    }

    _scheduleFlush();
  }

  // ============================================================
  // FLUSH SCHEDULING
  // ============================================================

  void _scheduleFlush() {
    if (_scheduled) return;

    _scheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_flush());
    });
  }

  // ============================================================
  // EXECUTION LOOP
  // ============================================================

  Future<void> _flush() async {
    _scheduled = false;

    if (_queue.isEmpty) {
      _updateMetrics();
      return;
    }

    final count = _queue.length < maxTasksPerFrame
        ? _queue.length
        : maxTasksPerFrame;

    final batch = _queue.sublist(0, count);
    _queue.removeRange(0, count);

    _updateMetrics();

    for (final task in batch) {
      try {
        await task();
      } catch (_) {
        /// isolate failure, but DO NOT break pipeline
      }
    }

    _updateMetrics();

    if (_queue.isNotEmpty) {
      _scheduleFlush();
    }
  }

  // ============================================================
  // MANUAL CONTROL
  // ============================================================

  Future<void> flushNow() async {
    while (_queue.isNotEmpty) {
      await _flush();
    }
  }

  // ============================================================
  // METRICS
  // ============================================================

  void _updateMetrics() {
    _backlog = _queue.length;

    onMetricsUpdate?.call(
      _backlog,
      _queue.length,
    );
  }

  // ============================================================
  // READ API
  // ============================================================

  int get backlog => _backlog;

  int get queueSize => _queue.length;

  int get droppedTasks => _droppedTasks;

  bool get hasPendingTasks => _queue.isNotEmpty;
}