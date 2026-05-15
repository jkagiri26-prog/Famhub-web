import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';
import '../../../../shared/widgets/headers/section_header_widget.dart';
import '../../../../shared/widgets/layout/section_container_widget.dart';

import '../widgets/traceability_certificate_header_widget.dart';
import '../widgets/traceability_info_tile_widget.dart';
import '../widgets/traceability_ledger_timeline_tile_widget.dart';
import '../widgets/traceability_qr_section_widget.dart';

/// FAMHUB Traceability Module
///
/// Architecture Compliance:
/// - No Scaffold
/// - No AppBar
/// - No Drawer
/// - No BottomNavigationBar
/// - ResponsiveWrapperWidget enforced
/// - Shared widgets first
/// - Feature widgets only for domain-specific UI

class TraceabilityPage extends StatelessWidget {
  const TraceabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ResponsiveWrapperWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            /// Shared Header
            ModuleHeaderWidget(
              title: 'Traceability',
              subtitle: 'Certificate ? Ledger ? Verification',
              trailingIcon: Icons.verified_user_outlined,
              onTrailingTap: () {},
            ),

            const SizedBox(height: 16),

            /// Feature-specific blockchain identity card
            const TraceabilityCertificateHeaderWidget(),

            const SizedBox(height: 16),

            /// Tabs
            const TabBar(
              tabs: [
                Tab(text: 'CERTIFICATE'),
                Tab(text: 'LEDGER LOGS'),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                children: [
                  _CertificateTab(),
                  _LedgerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SectionHeaderWidget(
          title: 'Certificate Details',
        ),

        SizedBox(height: 12),

        TraceabilityInfoTileWidget(
          label: 'Crop Variety',
          value: 'Organic Arabica Coffee',
        ),

        TraceabilityInfoTileWidget(
          label: 'Farmer ID',
          value: 'KE-CENTRAL-042',
        ),

        TraceabilityInfoTileWidget(
          label: 'Soil Quality Index',
          value: '8.5 (Verified)',
        ),

        TraceabilityInfoTileWidget(
          label: 'Last Fertilizer Log',
          value: 'N/A - 100% Organic',
        ),

        SizedBox(height: 20),

        TraceabilityQrSectionWidget(),

        SizedBox(height: 80),
      ],
    );
  }
}

class _LedgerTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logs = [
      {
        'event': 'Seed Dispatched',
        'time': 'Feb 01, 2026',
        'hash': '0x4f...2a',
      },
      {
        'event': 'Planting Verified',
        'time': 'Feb 03, 2026',
        'hash': '0x91...bc',
      },
      {
        'event': 'Moisture Check',
        'time': 'Feb 08, 2026',
        'hash': '0x12...ff',
      },
    ];

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final item = logs[index];

        return TraceabilityLedgerTimelineTileWidget(
          event: item['event']!,
          time: item['time']!,
          transactionHash: item['hash']!,
          isLast: index == logs.length - 1,
        );
      },
    );
  }
}