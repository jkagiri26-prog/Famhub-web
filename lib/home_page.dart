import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeTab = 'Discover';
  final PageController _heroController = PageController();
  final ScrollController _tickerController = ScrollController();
  int _currentPage = 0;
  Timer? _heroTimer;
  Timer? _tickerTimer;

  final List<String> _allModules = [
    "🛒 Marketplace", "📊 Market Data", "💰 Finance", "🧑‍🌾 Farmer Suite", 
    "🌱 Inputs", "📡 IoT", "📖 Guides", "📢 Extension", "🏗️ Agribusiness", 
    "🚚 Logistics", "🤝 Social", "📈 Analytics", "🗺️ Land", "👷 Labour", 
    "🛠️ Tools", "💡 Opportunities", "🏭 Value Addition", "🛡️ Security", 
    "☁️ Weather", "🧪 Innovation", "🗣️ Forums", "🤖 AI Doc", 
    "🎟️ Referral", "📋 Reports"
  ];

  @override
  void initState() {
    super.initState();
    _startEngines();
  }

  // OPTIMIZED ENGINES: Reduced frequency to save battery while maintaining smoothness
  void _startEngines() {
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (t) {
      if (_heroController.hasClients && mounted) {
        _currentPage = (_currentPage + 1) % 2; 
        _heroController.animateToPage(
          _currentPage, 
          duration: const Duration(milliseconds: 1200), 
          curve: Curves.easeInOutCubic
        );
      }
    });
    
    // Smooth ticker logic: check for 'mounted' to prevent post-dispose errors
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 32), (t) {
      if (_tickerController.hasClients && mounted) {
        double newOffset = _tickerController.offset + 0.6;
        if (newOffset >= _tickerController.position.maxScrollExtent) {
          _tickerController.jumpTo(0);
        } else {
          _tickerController.jumpTo(newOffset);
        }
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _tickerTimer?.cancel();
    _heroController.dispose();
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Root constraint check as per Protocol
    return Container(
      width: double.infinity,
      color: const Color(0xFFF4F7F4),
      child: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 90)), 
              _buildTabs(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildCleanSplitHero(),
                    const SizedBox(height: 24),
                    _buildPlainPulse(),
                    const SizedBox(height: 32),
                    _buildThinHeader("VALUE CHAIN", "Market Hotspots"),
                    const SizedBox(height: 12),
                    _buildGISMapModule(), 
                    const SizedBox(height: 32),
                    _buildThinHeader("DIAGNOSTICS", "AI Doc Assistant"),
                    const SizedBox(height: 12),
                    _buildAIDocModule(),
                    const SizedBox(height: 40),
                    _buildThinHeader("ECOSYSTEM", "All Modules"), 
                    const SizedBox(height: 12),
                    // REPAINT BOUNDARY: Isolates the moving ticker from the rest of the UI
                    RepaintBoundary(child: _buildInfiniteRibbon()), 
                    const SizedBox(height: 40),
                    _buildThinHeader("MARKETPLACE", "Trending Inputs"),
                    const SizedBox(height: 12),
                    _buildMarketplaceHorizontal(),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          _buildGlobalSearchBar(),
        ],
      ),
    );
  }

  // --- OPTIMIZED MODULES ---

  Widget _buildGlobalSearchBar() {
    return Positioned(
      top: 10, left: 16, right: 16,
      child: SafeArea(
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: const Row(
            children: [
              SizedBox(width: 16),
              Icon(Icons.search_rounded, color: Color(0xFF1B5E20), size: 22),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(hintText: "Search prices, 'AI Doc'...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 13, color: Colors.black26)))),
              VerticalDivider(indent: 15, endIndent: 15, width: 20),
              Icon(Icons.qr_code_scanner_rounded, color: Colors.black38, size: 20),
              SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfiniteRibbon() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _tickerController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.03))
          ),
          alignment: Alignment.center,
          child: Text(_allModules[i % _allModules.length], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildGISMapModule() {
    return Container(
      height: 220,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: "https://images.unsplash.com/photo-1524661135-423995f22d0b",
                fit: BoxFit.cover,
                memCacheHeight: 400, // Speed Optimization: Don't load full res
              ),
            ),
            Container(color: const Color(0xFF1B5E20).withOpacity(0.15)),
            const Center(child: Icon(Icons.location_on, color: Color(0xFFC6FF00), size: 36)),
          ],
        ),
      ),
    );
  }

  Widget _buildAIDocModule() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF002E28),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Color(0xFFC6FF00), size: 30),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("AI Diagnostic Hub", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            Text("Powered by FamHub Neural Engine", style: TextStyle(color: Colors.white54, fontSize: 10)),
          ])),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
          )
        ],
      ),
    );
  }

  Widget _buildCleanSplitHero() {
    return Container(
      height: 190,
      decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(24)),
      child: const Center(child: Text("Dynamic Hero Slider", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildPlainPulse() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _pulseStat("2.4M", "ACTIVE USERS"),
      _pulseStat("14.2B", "GMV (KES)"),
      _pulseStat("98%", "SATISFACTION"),
    ]);
  }

  Widget _pulseStat(String v, String l) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
      Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 0.5)),
    ]);
  }

  Widget _buildThinHeader(String l, String t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20), letterSpacing: 1.2)),
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)),
        ]),
        const Text("VIEW ALL", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black38)),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = ["Discover", "Marketplace", "Analytics", "Ecosystem"];
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 52,
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Text(tabs[i], style: TextStyle(fontSize: 13, fontWeight: _activeTab == tabs[i] ? FontWeight.w900 : FontWeight.w500, color: _activeTab == tabs[i] ? Colors.black : Colors.black26)),
        ),
      ),
    );
  }

  Widget _buildMarketplaceHorizontal() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, i) => Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        ),
      ),
    );
  }
}