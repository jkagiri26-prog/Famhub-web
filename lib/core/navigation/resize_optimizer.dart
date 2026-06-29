/// ============================================================
/// RESIZE OPTIMIZATION — BREAKPOINT-AWARE DEBOUNCING
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Debounce layout rebuilds during resize
///   - Only rebuild when crossing breakpoints
///   - Prevent continuous LayoutBuilder rebuilds
///   - Expose reactive breakpoint state via Riverpod
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Render widgets directly
///   - Store UI state
/// ============================================================
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/responsive_breakpoints.dart';

/// ============================================================
/// BREAKPOINT STATE
/// ============================================================
class BreakpointState {
  /// Current device type: 'mobile', 'tablet', 'desktop'
  final String deviceType;

  /// Current width
  final double width;

  /// Previous device type (for transition detection)
  final String? previousDeviceType;

  /// Whether we just crossed a breakpoint
  final bool justCrossedBreakpoint;

  const BreakpointState({
    required this.deviceType,
    required this.width,
    this.previousDeviceType,
    this.justCrossedBreakpoint = false,
  });

  BreakpointState copyWith({
    String? deviceType,
    double? width,
    String? previousDeviceType,
    bool? justCrossedBreakpoint,
  }) {
    return BreakpointState(
      deviceType: deviceType ?? this.deviceType,
      width: width ?? this.width,
      previousDeviceType: previousDeviceType ?? this.previousDeviceType,
      justCrossedBreakpoint: justCrossedBreakpoint ?? this.justCrossedBreakpoint,
    );
  }

  int get columnCount {
    switch (deviceType) {
      case 'mobile':
        return 1;
      case 'tablet':
        return 2;
      case 'desktop':
        return 3;
      default:
        return 3;
    }
  }

  double get spacing {
    switch (deviceType) {
      case 'mobile':
        return 8;
      case 'tablet':
        return 12;
      case 'desktop':
        return 16;
      default:
        return 16;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakpointState &&
          deviceType == other.deviceType &&
          width == other.width &&
          previousDeviceType == other.previousDeviceType &&
          justCrossedBreakpoint == other.justCrossedBreakpoint;

  @override
  int get hashCode => Object.hash(
        deviceType,
        width,
        previousDeviceType,
        justCrossedBreakpoint,
      );
}

/// ============================================================
/// BREAKPOINT NOTIFIER
/// ============================================================
///
/// Tracks the current breakpoint and debounces updates.
/// Only emits new state when crossing breakpoint thresholds.
/// Uses Riverpod 3 Notifier pattern.
/// ============================================================
class BreakpointNotifier extends Notifier<BreakpointState> {
  static const _debounceDuration = Duration(milliseconds: 100);

  Timer? _debounceTimer;

  @override
  BreakpointState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const BreakpointState(
      deviceType: 'desktop',
      width: 1440,
    );
  }

  void updateWidth(double width) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _evaluateWidth(width);
    });
  }

  void setInitialWidth(double width) {
    _evaluateWidth(width);
  }

  void _evaluateWidth(double width) {
    final newType = _deviceTypeFor(width);
    final prevType = state.deviceType;

    if (newType != prevType || state.width == 0) {
      state = BreakpointState(
        deviceType: newType,
        width: width,
        previousDeviceType: prevType,
        justCrossedBreakpoint: true,
      );

      Future.microtask(() {
        state = state.copyWith(justCrossedBreakpoint: false);
      });
    }
  }

  String _deviceTypeFor(double width) {
    return ResponsiveBreakpoints.labelFor(width);
  }
}

/// ============================================================
/// PROVIDERS
/// ============================================================

final breakpointProvider =
    NotifierProvider<BreakpointNotifier, BreakpointState>(
  BreakpointNotifier.new,
);

final deviceTypeProvider = Provider<String>((ref) {
  return ref.watch(breakpointProvider).deviceType;
});

final columnCountProvider = Provider<int>((ref) {
  return ref.watch(breakpointProvider).columnCount;
});

/// ============================================================
/// BREAKPOINT-AWARE LAYOUT BUILDER
/// ============================================================
class BreakpointAwareLayoutBuilder extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, BreakpointState breakpoint) builder;

  const BreakpointAwareLayoutBuilder({
    super.key,
    required this.builder,
  });

  @override
  ConsumerState<BreakpointAwareLayoutBuilder> createState() =>
      _BreakpointAwareLayoutBuilderState();
}

class _BreakpointAwareLayoutBuilderState
    extends ConsumerState<BreakpointAwareLayoutBuilder> {
  @override
  Widget build(BuildContext context) {
    final breakpoint = ref.watch(breakpointProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        ref.read(breakpointProvider.notifier).updateWidth(constraints.maxWidth);
        return widget.builder(context, breakpoint);
      },
    );
  }
}
