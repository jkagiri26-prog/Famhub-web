import 'package:flutter/material.dart';

/// FAMHUB Blockchain Traceability Module
/// Features: Smart Seed Suggestions, Immutable Ledger UI, Certificate View.
/// Standards: width: double.infinity, 16.0 Padding, No Scaffold.
class TraceabilityPage extends StatelessWidget {
  const TraceabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8.0),
            _buildBlockchainHeader(context),
            const SizedBox(height: 16.0),
            
            TabBar(
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.outline,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'CERTIFICATE'),
                Tab(text: 'LEDGER LOGS'),
              ],
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCertificateTab(context),
                  _buildLedgerTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockchainHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Immutable Traceability ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text("FH-9923-BLOCK-KNY-01", style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateTab(BuildContext context) {
    return ListView(
      children: [
        _buildInfoTile("Crop Variety", "Organic Arabica Coffee"),
        _buildInfoTile("Farmer ID", "KE-CENTRAL-042"),
        _buildInfoTile("Soil Quality Index", "8.5 (Verified)"),
        _buildInfoTile("Last Fertilizer Log", "N/A - 100% Organic"),
        const SizedBox(height: 20),
        Image.network(
          'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=FAMHUB_VERIFIED_9923',
          height: 150,
        ),
        const Center(child: Text("Scan to verify on FAMHUB Ledger", style: TextStyle(fontSize: 10))),
      ],
    );
  }

  Widget _buildLedgerTab(BuildContext context) {
    final steps = [
      {"event": "Seed Dispatched", "time": "Feb 01, 2026", "hash": "0x4f...2a"},
      {"event": "Planting Verified", "time": "Feb 03, 2026", "hash": "0x91...bc"},
      {"event": "Moisture Check", "time": "Feb 08, 2026", "hash": "0x12...ff"},
    ];

    return ListView.builder(
      itemCount: steps.length,
      itemBuilder: (context, index) {
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked, size: 16, color: Theme.of(context).colorScheme.primary),
                  if (index != steps.length - 1) Expanded(child: VerticalDivider(color: Theme.of(context).colorScheme.primary, thickness: 2)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[index]["event"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(steps[index]["time"]!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("TX: ${steps[index]["hash"]}", style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Divider(),
        ],
      ),
    );
  }
}