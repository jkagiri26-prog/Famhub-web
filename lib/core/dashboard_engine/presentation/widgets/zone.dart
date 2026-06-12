import 'package:flutter/material.dart';

class Zone extends StatefulWidget {
  const Zone({
    super.key,
    required this.zoneId,
    required this.child,
    required this.isDirty,
    this.onCleared,
  });

  final String zoneId;
  final Widget child;

  /// Derived from SnapshotDiff / PatchExecutor
  final bool isDirty;

  /// Optional callback instead of provider mutation
  final VoidCallback? onCleared;

  @override
  State<Zone> createState() => _ZoneState();
}

class _ZoneState extends State<Zone> {
  bool _hasReset = false;

  @override
  void didUpdateWidget(covariant Zone oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// Only react when dirty state changes to true
    if (widget.isDirty && !_hasReset) {
      _hasReset = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        /// ❌ NO PROVIDER CALLS
        /// ✔ pure UI callback hook
        widget.onCleared?.call();
      });
    }

    /// reset internal guard when clean
    if (!widget.isDirty) {
      _hasReset = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: widget.child,
    );
  }
}