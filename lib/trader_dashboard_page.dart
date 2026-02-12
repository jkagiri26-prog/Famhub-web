import 'package:flutter/material.dart';

/// FAMHUB Trader Dashboard: Integrated Order Management
/// Constraints: Root Container, No Scaffold, Betpawa Spacing (16.0 horizontal)
class TraderDashboardPage extends StatefulWidget {
  const TraderDashboardPage({super.key});

  @override
  State<TraderDashboardPage> createState() => _TraderDashboardPageState();
}

class _TraderDashboardPageState extends State<TraderDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  String _activeSourcingFilter = "Marketplace"; // Sub-filter for Sourcing Tab

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 8.0), // Standard minimal top padding
          
          // --- Main Category Navigation ---
          TabBar(
            controller: _mainTabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: "OVERVIEW"),
              Tab(text: "SOURCING"),
              Tab(text: "SUPPLYING"),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                _buildOverviewTab(theme),
                _buildSourcingTab(theme), // Buyer's Marketplace + Orders
                _buildSupplyingTab(theme), // Seller's Shop
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SOURCING TAB (BUYER VIEW) ---
  Widget _buildSourcingTab(ThemeData theme) {
    return Column(
      children: [
        // Sub-filters specifically for Buyers
        _buildSubFilterRow(
          ["Marketplace", "My Orders", "Wishlist", "Invoices"],
          _activeSourcingFilter,
          (val) => setState(() => _activeSourcingFilter = val),
        ),
        
        Expanded(
          child: _activeSourcingFilter == "My Orders" 
            ? _buildBuyerOrdersList(theme) 
            : _buildSourcingMarketplace(theme),
        ),
      ],
    );
  }

  // --- BUYER ORDER MANAGEMENT VIEW ---
  Widget _buildBuyerOrdersList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        _buildOrderCard(
          id: "#ORD-7721",
          item: "Hybrid Maize Seeds",
          supplier: "GreenField Supplies",
          status: "In Transit",
          statusColor: Colors.blue,
          amount: "KES 12,800",
        ),
        _buildOrderCard(
          id: "#ORD-7719",
          item: "NPK Fertilizer (50kg)",
          supplier: "AgroChem Ltd",
          status: "Processing",
          statusColor: Colors.orange,
          amount: "KES 6,400",
        ),
        _buildOrderCard(
          id: "#ORD-7680",
          item: "Hand Planter Tool",
          supplier: "GreenField Supplies",
          status: "Delivered",
          statusColor: Colors.green,
          amount: "KES 12,500",
        ),
        const SizedBox(height: 20),
        _placeholderBox("Archived Orders (2025)", height: 80),
      ],
    );
  }

  Widget _buildOrderCard({
    required String id,
    required String item,
    required String supplier,
    required String status,
    required Color statusColor,
    required String amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                height: 40, width: 40,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("Supplier: $supplier", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text("Track", style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text("Reorder", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- PLACEHOLDERS FOR OTHER TABS ---
  Widget _buildOverviewTab(ThemeData theme) => Center(child: _placeholderBox("Trade Analytics Overview"));
  
  Widget _buildSourcingMarketplace(ThemeData theme) => _placeholderBox("Buyer Marketplace Feed");

  Widget _buildSupplyingTab(ThemeData theme) => _placeholderBox("Sellers Shop Management");

  // --- SHARED UI HELPERS ---
  Widget _buildSubFilterRow(List<String> filters, String active, Function(String) onSelect) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isSelected = active == filters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filters[index]),
              selected: isSelected,
              onSelected: (val) => onSelect(filters[index]),
              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderBox(String text, {double height = 100}) {
    return Container(
      height: height,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    );
  }
}