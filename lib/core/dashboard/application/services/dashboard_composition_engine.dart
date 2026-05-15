import 'package:flutter/material.dart';

enum DashboardLayoutType {
  grid,
  split,
  stacked,
  mixed,
}

/// Zone-based layout input from renderer
class DashboardZoneData {
  final List<Widget> header;
  final List<Widget> main;
  final List<Widget> sidebar;
  final List<Widget> footer;

  const DashboardZoneData({
    required this.header,
    required this.main,
    required this.sidebar,
    required this.footer,
  });
}

/// ============================================================
/// DASHBOARD COMPOSITION ENGINE (TYPE-SAFE VERSION)
/// ============================================================
class DashboardCompositionEngine {
  Widget compose({
    required DashboardZoneData zones,
    required BuildContext context,
    required DashboardLayoutType layoutType,
  }) {
    switch (layoutType) {
      case DashboardLayoutType.grid:
        return _buildGrid(zones);

      case DashboardLayoutType.split:
        return _buildSplit(zones, context);

      case DashboardLayoutType.mixed:
        return _buildSplit(zones, context);

      case DashboardLayoutType.stacked:
      default:
        return _buildStacked(zones);
    }
  }

  // ============================================================
  // GRID LAYOUT
  // ============================================================
  Widget _buildGrid(DashboardZoneData zones) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ...zones.header,
          ...zones.main,
          ...zones.sidebar,
          ...zones.footer,
        ],
      ),
    );
  }

  // ============================================================
  // SPLIT LAYOUT
  // ============================================================
  Widget _buildSplit(DashboardZoneData zones, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    return Column(
      children: [
        if (zones.header.isNotEmpty)
          _wrapHeader(zones.header),

        Expanded(
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _wrapMain(zones.main),
                    ),
                    if (zones.sidebar.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: _wrapSidebar(zones.sidebar),
                      ),
                  ],
                )
              : ListView(
                  children: [
                    _wrapMain(zones.main),
                    if (zones.sidebar.isNotEmpty)
                      _wrapSidebar(zones.sidebar),
                  ],
                ),
        ),

        if (zones.footer.isNotEmpty)
          _wrapFooter(zones.footer),
      ],
    );
  }

  // ============================================================
  // STACKED LAYOUT
  // ============================================================
  Widget _buildStacked(DashboardZoneData zones) {
    return ListView(
      children: [
        if (zones.header.isNotEmpty)
          _wrapHeader(zones.header),

        _wrapMain(zones.main),

        if (zones.sidebar.isNotEmpty)
          _wrapSidebar(zones.sidebar),

        if (zones.footer.isNotEmpty)
          _wrapFooter(zones.footer),
      ],
    );
  }

  // ============================================================
  // WRAPPERS
  // ============================================================

  Widget _wrapHeader(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: children),
    );
  }

  Widget _wrapMain(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children,
      ),
    );
  }

  Widget _wrapSidebar(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: children),
    );
  }

  Widget _wrapFooter(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: children),
    );
  }
}