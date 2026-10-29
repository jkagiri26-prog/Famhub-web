import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDrillState {
  const AdminDrillState({
    this.taxonomyActive = false,
    this.taxonomyDepth = 0,
    this.locationsActive = false,
    this.locationsDepth = 0,
  });

  final bool taxonomyActive;
  final int taxonomyDepth;
  final bool locationsActive;
  final int locationsDepth;

  bool get hasActiveDrill =>
      (taxonomyActive && taxonomyDepth > 0) ||
      (locationsActive && locationsDepth > 0);

  AdminDrillState copyWith({
    bool? taxonomyActive,
    int? taxonomyDepth,
    bool? locationsActive,
    int? locationsDepth,
  }) {
    return AdminDrillState(
      taxonomyActive: taxonomyActive ?? this.taxonomyActive,
      taxonomyDepth: taxonomyDepth ?? this.taxonomyDepth,
      locationsActive: locationsActive ?? this.locationsActive,
      locationsDepth: locationsDepth ?? this.locationsDepth,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdminDrillState &&
      other.taxonomyActive == taxonomyActive &&
      other.taxonomyDepth == taxonomyDepth &&
      other.locationsActive == locationsActive &&
      other.locationsDepth == locationsDepth;

  @override
  int get hashCode =>
      Object.hash(taxonomyActive, taxonomyDepth, locationsActive, locationsDepth);
}

class AdminDrillController extends Notifier<AdminDrillState> {
  VoidCallback? _unwindTaxonomy;
  VoidCallback? _unwindLocations;

  @override
  AdminDrillState build() => const AdminDrillState();

  void setTaxonomy({
    required bool active,
    required int depth,
    VoidCallback? unwind,
  }) {
    _unwindTaxonomy = unwind;
    final next = state.copyWith(taxonomyActive: active, taxonomyDepth: depth);
    if (next != state) state = next;
  }

  void clearTaxonomy() {
    _unwindTaxonomy = null;
    final next = state.copyWith(taxonomyActive: false, taxonomyDepth: 0);
    if (next != state) state = next;
  }

  void setLocations({
    required bool active,
    required int depth,
    VoidCallback? unwind,
  }) {
    _unwindLocations = unwind;
    final next = state.copyWith(locationsActive: active, locationsDepth: depth);
    if (next != state) state = next;
  }

  void clearLocations() {
    _unwindLocations = null;
    final next = state.copyWith(locationsActive: false, locationsDepth: 0);
    if (next != state) state = next;
  }

  void clearAll() {
    _unwindTaxonomy = null;
    _unwindLocations = null;
    if (state != const AdminDrillState()) {
      state = const AdminDrillState();
    }
  }

  void unwindActive() {
    final current = state;
    if (current.taxonomyActive && current.taxonomyDepth > 0) {
      _unwindTaxonomy?.call();
    } else if (current.locationsActive && current.locationsDepth > 0) {
      _unwindLocations?.call();
    }
  }
}

/// Scoped to the Admin dashboard: the page's back gate is the only reader,
/// so the drill state is released when the page leaves the tree instead of
/// leaking stale depths/callbacks into a later visit.
final adminDrillProvider =
    NotifierProvider.autoDispose<AdminDrillController, AdminDrillState>(
  AdminDrillController.new,
);
