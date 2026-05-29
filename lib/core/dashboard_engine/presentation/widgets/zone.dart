import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/dashboard_zone_render_provider.dart';

class _Zone extends ConsumerStatefulWidget {
  const _Zone({
    required this.zoneId,
    required this.child,
    required this.isDirty,
  });

  final String zoneId;
  final Widget child;
  final bool isDirty;

  @override
  ConsumerState<_Zone> createState() => _ZoneState();
}

class _ZoneState extends ConsumerState<_Zone> {
  bool _hasReset = false;

  @override
  void didUpdateWidget(covariant _Zone oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// Reset only when zone transitions from dirty → clean
    if (widget.isDirty && !_hasReset) {
      _hasReset = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ref
            .read(dashboardZoneRenderProvider.notifier)
            .clearZone(widget.zoneId);
      });
    }

    if (!widget.isDirty) {
      _hasReset = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Always participate in rebuild cycle (Riverpod-safe)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: widget.child,
    );
  }
}