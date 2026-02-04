import 'package:flutter/material.dart';

/// FAMHUB Module: FarmerDashboard
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Style: Betpawa-inspired high-density dashboard with NestedScrollView.
class FarmerDashboardPage extends StatelessWidget {
  const FarmerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FarmerDashboardContent();
  }
}

class _FarmerDashboardContent extends StatefulWidget {
  const _FarmerDashboardContent();

  @override
  State<_FarmerDashboardContent> createState() => _FarmerDashboardContentState();
}

class _FarmerDashboardContentState extends State<_FarmerDashboardContent> with TickerProviderStateMixin {
  late TabController _tier2TabController;

  @override
  void initState() {
    super.initState();
    _tier2TabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tier2TabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: RepaintBoundary(child: _buildFeaturedCarousel(context, primary)),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabDelegate(
              TabBar(
                controller: _tier2TabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: primary,
                labelColor: primary,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Overview"), Tab(text: "My Farms"), Tab(text: "Crops"),
                  Tab(text: "Logs"), Tab(text: "Weather"), Tab(text: "Prices"), Tab(text: "Reports"),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tier2TabController,
          children: [
            _buildOverviewTab(context, primary),
            _buildPlaceholder("Farms Mapping (GIS)"),
            _buildCropsTab(context, primary),
            _buildPlaceholder("Offline Field Logs"),
            _buildPlaceholder("AI Weather Predictor"),
            _buildPlaceholder("Regional Price Ticker"),
            _buildPlaceholder("Compliance Reports"),
          ],
        ),
      ),
    );
  }

  // --- TIER 2: OVERVIEW ---
  Widget _buildOverviewTab(BuildContext context, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIAdvisoryCard(context),
          const SizedBox(height: 24),
          const Text("QUICK STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildQuickStatsRow(context),
          const SizedBox(height: 24),
          _buildBetPawaButton(context, "Open Marketplace", Icons.storefront, primary),
        ],
      ),
    );
  }

  Widget _buildCropsTab(BuildContext context, Color primary) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: ["All Plots", "Plot A", "Plot B"].map((chip) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(chip, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300),
                onPressed: () {},
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => _buildCropCard(context, primary),
          ),
        ),
      ],
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildFeaturedCarousel(BuildContext context, Color primary) {
    return Container(
      height: 140,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(4), // Square-ish "Betpawa" look
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("REAL-TIME UPDATES", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
            Spacer(),
            Text("Long Rains Advisory\nView Prep Guide", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAdvisoryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.green, size: 14),
              SizedBox(width: 8),
              Text("AI ADVISORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
            ],
          ),
          SizedBox(height: 8),
          Text("No humidity spikes detected. Risk of Maize Rust is currently LOW.", 
            style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(BuildContext context) {
    return Row(
      children: [
        _miniStat("Hectares", "12.5"),
        const SizedBox(width: 12),
        _miniStat("Net Value", "KSh 1.2M"),
      ],
    );
  }

  Widget _miniStat(String l, String v) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    ),
  );

  Widget _buildCropCard(BuildContext context, Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("POTATOES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const Spacer(),
          LinearProgressIndicator(
            value: 0.65, 
            color: primary, 
            backgroundColor: Colors.grey.shade100,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildBetPawaButton(BuildContext context, String text, IconData icon, Color primary) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Text(text.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String t) => Center(child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)));
}

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(context, offset, overlaps) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(old) => false;
}