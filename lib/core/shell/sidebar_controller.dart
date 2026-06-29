/// ============================================================
/// SIDEBAR CONTROLLER (RIVERPOD STATE MANAGEMENT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Manage sidebar expanded/collapsed state
///   - Persist state via SharedPreferences
///   - Provide animation-ready state
///   - Expose keyboard shortcut actions
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Render UI
///   - Know about navigation items
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// SIDEBAR STATE MODEL
/// ============================================================
class SidebarState {
  /// Whether the sidebar is expanded (true) or collapsed (false)
  final bool isExpanded;

  /// Whether an animation is currently in progress
  final bool isAnimating;

  /// The target width for animation
  final double targetWidth;

  const SidebarState({
    this.isExpanded = true,
    this.isAnimating = false,
    this.targetWidth = 260.0,
  });

  SidebarState copyWith({
    bool? isExpanded,
    bool? isAnimating,
    double? targetWidth,
  }) {
    return SidebarState(
      isExpanded: isExpanded ?? this.isExpanded,
      isAnimating: isAnimating ?? this.isAnimating,
      targetWidth: targetWidth ?? this.targetWidth,
    );
  }

  /// Width when expanded
  static const double expandedWidth = 260.0;

  /// Width when collapsed
  static const double collapsedWidth = 72.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarState &&
          isExpanded == other.isExpanded &&
          isAnimating == other.isAnimating &&
          targetWidth == other.targetWidth;

  @override
  int get hashCode => Object.hash(isExpanded, isAnimating, targetWidth);
}

/// ============================================================
/// SIDEBAR CONTROLLER (NOTIFIER)
/// ============================================================
///
/// Uses Riverpod 3's Notifier pattern (replaces StateNotifier).
  /// ============================================================
class SidebarController extends Notifier<SidebarState> {
  static const String _persistenceKey = 'sidebar_expanded';

  @override
  SidebarState build() {
    _loadPersistedState();
    return const SidebarState();
  }
  /// ============================================================
  /// LOAD PERSISTED STATE
  /// ============================================================
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_persistenceKey);
      if (saved != null && saved != state.isExpanded) {
        state = SidebarState(
          isExpanded: saved,
          targetWidth: saved
              ? SidebarState.expandedWidth
              : SidebarState.collapsedWidth,
        );
      }
    } catch (_) {
      // Silently fall back to default
    }
  }
  /// ============================================================
  /// PERSIST CURRENT STATE
  /// ============================================================
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_persistenceKey, state.isExpanded);
    } catch (_) {
      // Silently handle persistence failure
    }
  }
  /// ============================================================
  /// TOGGLE SIDEBAR
  /// ============================================================
  void toggle() {
    if (state.isExpanded) {
      collapse();
    } else {
      expand();
    }
  }
  /// ============================================================
  /// EXPAND SIDEBAR
  /// ============================================================
  void expand() {
    if (state.isExpanded) return;
    state = state.copyWith(
      isExpanded: true,
      isAnimating: true,
      targetWidth: SidebarState.expandedWidth,
    );
    _persist();
    // Animation is handled by the UI layer
    Future.delayed(const Duration(milliseconds: 200), () {
      state = state.copyWith(isAnimating: false);
    });
  }

  /// ============================================================
  /// COLLAPSE SIDEBAR
  /// ============================================================
  void collapse() {
    if (!state.isExpanded) return;
    state = state.copyWith(
      isExpanded: false,
      isAnimating: true,
      targetWidth: SidebarState.collapsedWidth,
    );
    _persist();
    Future.delayed(const Duration(milliseconds: 200), () {
      state = state.copyWith(isAnimating: false);
});
  }

  /// ============================================================
  /// SET EXPANDED DIRECTLY
  /// ============================================================
  void setExpanded(bool expanded) {
    if (expanded == state.isExpanded) return;
    if (expanded) {
      expand();
    } else {
      collapse();
    }
  }
}

/// ============================================================
/// PROVIDERS
/// ============================================================

/// Sidebar controller state notifier
final sidebarControllerProvider =
    NotifierProvider<SidebarController, SidebarState>(
  SidebarController.new,
);

/// Convenience provider for sidebar expanded state only
final sidebarExpandedProvider = Provider<bool>((ref) {
  return ref.watch(sidebarControllerProvider).isExpanded;
});

/// Convenience provider for sidebar target width
final sidebarWidthProvider = Provider<double>((ref) {
  final state = ref.watch(sidebarControllerProvider);
  return state.targetWidth;
});

