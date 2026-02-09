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
            
            const SizedBox(height: 12.0),
            
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

  // --- TAB 1: Digital Certificate & Sourcing ---
  Widget _buildCertificateTab(BuildContext context) {
    final theme = Theme.of(context);
    
    // Mock for Supabase suggest_seed_sources RPC
    const List<String> seedSuggestions = ["Kenya Seed Co", "Simlaw", "Pannar"];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSealCard(context),
          const SizedBox(height: 24),
          
          const Text("Enter/Verify Seed Source", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          
          // Smart Autocomplete using existing data
          Autocomplete<String>(
            optionsBuilder: (textValue) => textValue.text.isEmpty 
                ? [] 
                : seedSuggestions.where((s) => s.toLowerCase().contains(textValue.text.toLowerCase())),
            fieldViewBuilder: (ctx, ctrl, node, onSub) => TextField(
              controller: ctrl,
              focusNode: node,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.spoke, size: 18),
                hintText: "Start typing seed source...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _buildDetailRow(context, "Farmer Origin", "Samuel K. (Verified)", Icons.person_outline),
          _buildDetailRow(context, "Geographic Plot", "Field A1 - East Sector", Icons.map_outlined),
          _buildDetailRow(context, "System Hash", "sha256:0x8a...32", Icons.fingerprint),
          
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: (){}, child: const Text("GENERATE QR LABEL"))),
        ],
      ),
    );
  }

  // --- TAB 2: Immutable Ledger (Logs Chain) ---
  Widget _buildLedgerTab(BuildContext context) {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) => _LedgerNode(
        title: index == 0 ? "Genesis: Seed Recorded" : "Integrity Check #$index",
        hash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e$index",
        isLast: index == 3,
      ),
    );
  }

  // --- REUSABLE UI ---

  Widget _buildBlockchainHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Traceability', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }

  Widget _buildSealCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_2, size: 48),
          SizedBox(height: 8),
          Text("LEDGER SEAL ACTIVE", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("Data is immutable and timestamped", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String l, String v, IconData i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(i, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(l, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LedgerNode extends StatelessWidget {
  final String title, hash;
  final bool isLast;
  const _LedgerNode({required this.title, required this.hash, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Icon(Icons.link, color: theme.colorScheme.primary, size: 16),
          if (!isLast) Container(width: 1.5, height: 45, color: theme.colorScheme.outlineVariant),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(hash, style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
            const SizedBox(height: 16),
          ],
        )),
      ],
    );
  }
}