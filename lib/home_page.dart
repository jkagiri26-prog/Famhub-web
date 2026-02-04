import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// FAMHUB Module: HomePage
/// Protocol: Root width: double.infinity, No Scaffold, Standard Spacing.
/// Laws Applied: 0-Second Rule (Pre-cache), Betpawa Spacing (16.0), Repaint Isolation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeTab = 'Overview';
  final ScrollController _ribbonScroll = ScrollController();
  Timer? _ribbonTimer;

  static const double _betpawaPadding = 16.0;
  static const Color _brandDark = Color(0xFF002E28);

  @override
  void initState() {
    super.initState();
    _startRibbon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // LAW 4: THE 0-SECOND RULE (Pre-cache assets)
    precacheImage(const CachedNetworkImageProvider("https://images.unsplash.com/photo-1500382017468-9049fed747ef"), context);
  }

  void _startRibbon() {
    _ribbonTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (_ribbonScroll.hasClients && mounted) {
        if (_ribbonScroll.offset >= _ribbonScroll.position.maxScrollExtent) {
          _ribbonScroll.jumpTo(0);
        } else {
          _ribbonScroll.jumpTo(_ribbonScroll.offset + 0.5);
        }
      }
    });
  }

  @override
  void dispose() {
    _ribbonTimer?.cancel();
    _ribbonScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: CustomScrollView(
        slivers: [
          _buildTier2Navigation(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _betpawaPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildEliteSlantHero(),
                const SizedBox(height: 24),
                _buildBentoStatusGrid(),
                const SizedBox(height: 24),
                _buildOptimizedRibbon(), 
                const SizedBox(height: 24),
                _buildQuickAccessGrid(),
                const SizedBox(height: 120), 
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTier2Navigation() {
    final navItems = ["Overview", "My Farm", "Market Trends", "Ecosystem"];
    return SliverAppBar(
      pinned: true,
      elevation: 0.5,
      toolbarHeight: 48,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      flexibleSpace: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: navItems.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => setState(() => _activeTab = navItems[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                color: _activeTab == navItems[i] ? Theme.of(context).colorScheme.primary : Colors.transparent,
                width: 2.5,
              )),
            ),
            child: Text(navItems[i], style: TextStyle(
              fontSize: 14, fontWeight: _activeTab == navItems[i] ? FontWeight.bold : FontWeight.w500,
              color: _activeTab == navItems[i] ? Colors.black : Colors.grey.shade600,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedRibbon() {
    final items = ["LOGISTICS", "FINANCE", "VET SERVICES", "SOIL TESTING", "MARKET DATA"];
    return RepaintBoundary( 
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          controller: _ribbonScroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, i) => Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            alignment: Alignment.center,
            child: Text(items[i % items.length], style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, 
              color: Theme.of(context).colorScheme.primary, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _buildEliteSlantHero() {
    return Container(
      height: 220,
      decoration: BoxDecoration(color: _brandDark, borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("WELCOME", style: TextStyle(color: Color(0xFFC6FF00), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text("FamHub\nPortal", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.05)),
                ],
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.65,
                  child: ClipPath(
                    clipper: HomeHeroClipper(),
                    child: CachedNetworkImage(
                      imageUrl: "https://images.unsplash.com/photo-1500382017468-9049fed747ef",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.black12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoStatusGrid() {
    return Row(
      children: [
        _bentoCard("24°C", "Sunny • Nakuru", Icons.wb_sunny_outlined),
        const SizedBox(width: 12),
        _bentoCard("KES 3,4K", "Maize ▲ 2%", Icons.insights),
      ],
    );
  }

  Widget _bentoCard(String v, String s, IconData i) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final tools = [
      {"n": "Input Credit", "i": Icons.add_card},
      {"n": "Farm Logs", "i": Icons.history_edu},
      {"n": "Hire Tractor", "i": Icons.agriculture},
      {"n": "Expert Chat", "i": Icons.support_agent},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.8),
      itemCount: tools.length,
      itemBuilder: (context, i) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tools[i]['i'] as IconData, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            Text(tools[i]['n'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class HomeHeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width * 0.28, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override bool shouldReclip(CustomClipper<Path> old) => false;
}