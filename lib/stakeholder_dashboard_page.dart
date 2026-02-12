import 'package:flutter/material.dart';

class StakeholderDashboardPage extends StatelessWidget {
  const StakeholderDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Container(
        width: double.infinity,
        // FAMHUB "Betpawa" Spacing Rule
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(theme),
            const SizedBox(height: 12),
            
            // Stakeholder Category Tabs
            TabBar(
              isScrollable: true,
              indicatorWeight: 3,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Financials"),
                Tab(text: "Inputs & Tools"),
                Tab(text: "Factories"),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildFinancialsTab(theme),
                  _buildInputsTab(theme),
                  _buildFactoriesTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Stakeholder Hub",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          "Oversight for Banks, Saccos, Suppliers, and Processors.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }

  // TAB 1: Banks & Saccos
  Widget _buildFinancialsTab(ThemeData theme) {
    return _buildTabContent(
      theme,
      icon: Icons.account_balance,
      metricLabel: "Total Credit Disbursed",
      metricValue: "KSh 4.2M",
      metricColor: Colors.blue.shade700,
      partners: [
        {'name': 'Stima Sacco', 'sub': '1.2k Members', 'status': '98% Health'},
        {'name': 'Equity Bank', 'sub': 'Value Chain Loan', 'status': 'Active'},
      ],
    );
  }

  // TAB 2: Input Providers
  Widget _buildInputsTab(ThemeData theme) {
    return _buildTabContent(
      theme,
      icon: Icons.handyman,
      metricLabel: "Active Inventory Items",
      metricValue: "840 Units",
      metricColor: Colors.orange.shade800,
      partners: [
        {'name': 'Bayer East Africa', 'sub': 'Fertilizer Supply', 'status': 'Stocked'},
        {'name': 'Syngenta', 'sub': 'Seed Distribution', 'status': 'Low Stock'},
      ],
    );
  }

  // TAB 3: Factories & Buyers
  Widget _buildFactoriesTab(ThemeData theme) {
    return _buildTabContent(
      theme,
      icon: Icons.factory,
      metricLabel: "Total Intake Volume",
      metricValue: "45.2 Tons",
      metricColor: Colors.brown.shade600,
      partners: [
        {'name': 'Nyeri Coffee Factory', 'sub': 'Daily Intake: 2.1T', 'status': 'Processing'},
        {'name': 'Dorman Exporters', 'sub': 'Export Quality Audit', 'status': 'Pending'},
      ],
    );
  }

  // Reusable Component for all Tabs
  Widget _buildTabContent(
    ThemeData theme, {
    required IconData icon,
    required String metricLabel,
    required String metricValue,
    required Color metricColor,
    required List<Map<String, String>> partners,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Metric Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: metricColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: metricColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: metricColor, size: 30),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metricLabel, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text(metricValue, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: metricColor)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Active Partners", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        // Partner List
        ...partners.map((p) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(p['sub']!),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        )).toList(),
      ],
    );
  }
}