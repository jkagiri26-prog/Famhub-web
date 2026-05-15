import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/dashboard_descriptor.dart';

import 'dashboard_layout_compiler.dart';
import 'dashboard_diff_engine.dart';
import 'dashboard_usage_tracker.dart';
import 'device_layout_service.dart';

import '../resolvers/widget_resolver_service.dart';
import '../resolvers/widget_render_cache.dart';

class DashboardRendererService {
  final WidgetResolverService widgetResolver;
  final DashboardLayoutCompiler layoutCompiler;
  final DashboardDiffEngine diffEngine;
  final DashboardUsageTracker usageTracker;

  final WidgetRenderCache _cache = WidgetRenderCache();

  List<DashboardDescriptor> _previous = const [];

  DashboardRendererService({
    required this.widgetResolver,
    required this.usageTracker,
    DashboardLayoutCompiler? layoutCompiler,
    DashboardDiffEngine? diffEngine,
  })  : layoutCompiler = layoutCompiler ?? DashboardLayoutCompiler(),
        diffEngine = diffEngine ?? DashboardDiffEngine();

  Map<String, List<Widget>> renderByZones(
    List<DashboardDescriptor> descriptors,
    WidgetRef ref,
    BuildContext context,
  ) {
    final device = DeviceLayoutService.getDeviceType(context);

    // =========================
    // STEP 1: DEVICE FILTER
    // =========================
    final filtered = _filterByDevice(descriptors, device);

    // =========================
    // STEP 2: DIFF
    // =========================
    final diff = diffEngine.diff(_previous, filtered);
    _previous = filtered;

    final updatedIds = diff.updated.map((e) => e.id).toSet();
    final removedIds = diff.removed.map((e) => e.id).toSet();

    // =========================
    // STEP 3: ORDERING (single system only)
    // =========================
    final ordered = layoutCompiler.compile(filtered);

    final zones = _initZones();

    // =========================
    // STEP 4: RENDER
    // =========================
    for (final descriptor in ordered) {
      if (removedIds.contains(descriptor.id)) continue;

      final zone = descriptor.layoutZone;

      final cached = _cache.get(descriptor.widgetKey);

      final needsRebuild =
          cached == null || updatedIds.contains(descriptor.id);

      final widget = needsRebuild
          ? _buildWidget(descriptor, ref)
          : cached;

      if (widget == null) continue;

      _cache.set(descriptor.widgetKey, widget);
      zones[zone]!.add(widget);

      usageTracker.trackOpen(descriptor.widgetKey);
    }

    // =========================
    // STEP 5: PRELOAD (safe snapshot)
    // =========================
    _preload(filtered, ref);

    return zones;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  List<DashboardDescriptor> _filterByDevice(
    List<DashboardDescriptor> descriptors,
    DeviceType device,
  ) {
    return descriptors.where((d) {
      return switch (device) {
        DeviceType.mobile => d.mobileVisibility,
        DeviceType.tablet => d.tabletVisibility,
        DeviceType.desktop => d.desktopVisibility,
      };
    }).toList();
  }

  Map<String, List<Widget>> _initZones() {
    return {
      'header': [],
      'main': [],
      'sidebar': [],
      'footer': [],
    };
  }

  Widget? _buildWidget(
    DashboardDescriptor descriptor,
    WidgetRef ref,
  ) {
    return widgetResolver.resolve(
      descriptor.widgetKey,
      descriptor.config,
      ref,
    );
  }

  void _preload(
    List<DashboardDescriptor> descriptors,
    WidgetRef ref,
  ) {
    Future.microtask(() {
      for (final d in descriptors) {
        if (_cache.get(d.widgetKey) != null) continue;

        final widget = widgetResolver.resolve(
          d.widgetKey,
          d.config,
          ref,
        );

        if (widget != null) {
          _cache.set(d.widgetKey, widget);
        }
      }
    });
  }
}