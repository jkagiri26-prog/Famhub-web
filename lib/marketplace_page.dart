import 'dart:async';
import 'package:flutter/material.dart';

/// FAMHUB Module: Marketplace (Performance Optimized)
/// Logic: RepaintBoundaries for animations, Const constructors, Lazy rendering.
class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; 

  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;
  int _currentAdIndex = 0;
  Timer? _rotationTimer;
  String _activeTab = "ALL";

  final List<String> _filterTabs = const ["ALL", "LIVESTOCK", "CROPS", "INPUTS", "MACHINERY", "SERVICES"];
  
  static const Color primaryGreen = Color(0xFF2E7D32); 
  static const Color canvasGrey = Color(0xFFEDF0F3);

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_carouselController.hasClients) {
        _currentCarouselPage = (_currentCarouselPage + 1) % 3;
        _carouselController.animateToPage(_currentCarouselPage, 
          duration: const Duration(milliseconds: 600), curve: Curves.decelerate);
      }
      if (timer.tick % 2 == 0) { 
        setState(() => _currentAdIndex = (_currentAdIndex + 1) % 2);
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return Container(
      width: double.infinity,
      color: canvasGrey,
      child: Column(
        children: [
          RepaintBoundary(child: _buildTripleHeader()),
          _buildSearchAndFilterArea(),
          Expanded(
            child: ListView(
              cacheExtent: 500, 
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDynamicFeaturedIsland(),
                if (_activeTab == "ALL" || _activeTab == "LIVESTOCK")
                  _buildSubcategoryIsland("LIVESTOCK", [{"n": "Dairy Cow", "d": "1.2km"}, {"n": "Beef Bull", "d": "4.5km"}]),
                if (_activeTab == "ALL" || _activeTab == "CROPS")
                  _buildSubcategoryIsland("CROPS", [{"n": "Yellow Maize", "d": "0.8km"}, {"n": "Red Onions", "d": "12km"}]),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripleHeader() {
    return Container(
      height: 125,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildStaticAnchor()),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _buildAutoCarousel()),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _buildManagedAdSpace()),
        ],
      ),
    );
  }

  Widget _buildStaticAnchor() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryGreen, Color(0xFF43A047)]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_shopping_cart, color: Colors.white, size: 22),
          SizedBox(height: 4),
          Text("SELL\nNOW", textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildAutoCarousel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: canvasGrey, borderRadius: BorderRadius.circular(6)),
      child: PageView.builder( 
        controller: _carouselController,
        itemCount: 3,
        itemBuilder: (context, index) {
          final List<Color> colors = [Colors.orange.shade700, Colors.blue.shade700, Colors.purple.shade700];
          return Container(
            color: colors[index],
            // FIXED: Icons.local_offer instead of Icons.LocalOffer
            child: const Center(child: Icon(Icons.local_offer, color: Colors.white24, size: 40)),
          );
        },
      ),
    );
  }

  Widget _buildManagedAdSpace() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: Container(
        key: ValueKey<int>(_currentAdIndex),
        decoration: BoxDecoration(
          color: _currentAdIndex == 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(6)
        ),
        child: Center(
          child: Text(_currentAdIndex == 0 ? "SEED\nCO." : "TOYOTA\nAGRI",
            textAlign: TextAlign.center, 
            style: TextStyle(
              color: _currentAdIndex == 0 ? Colors.red.shade700 : Colors.blue.shade900, 
              fontSize: 10, fontWeight: FontWeight.w900)
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterArea() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            height: 40,
            decoration: BoxDecoration(color: canvasGrey, borderRadius: BorderRadius.circular(4)),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search nearest...", 
                prefixIcon: Icon(Icons.search, size: 18), 
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9)
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterTabs.length,
              itemBuilder: (c, i) {
                final isMe = _activeTab == _filterTabs[i];
                return GestureDetector(
                  onTap: () => setState(() => _activeTab = _filterTabs[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(
                      color: isMe ? Colors.orange : Colors.transparent, width: 2))),
                    child: Text(_filterTabs[i], style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, 
                      color: isMe ? Colors.orange : Colors.black54)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryIsland(String title, List<Map<String, String>> items) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: canvasGrey))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.orange),
              ],
            ),
          ),
          SizedBox(
            height: 235,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) => _buildDetailedCard(items[i]['n']!, items[i]['d']!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCard(String name, String distance) {
    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: canvasGrey)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(height: 90, width: double.infinity, color: canvasGrey, 
                child: const Icon(Icons.image_outlined, color: Colors.black12)),
              Positioned(top: 5, left: 5, child: _badge(distance, Colors.black87)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
                const Text("KSh 3,250", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _actionBtn("AI CHAT SELLER", primaryGreen.withOpacity(0.1), primaryGreen, Icons.auto_awesome),
                const SizedBox(height: 4),
                _actionBtn("LOCKED CONTACT", Colors.black87, Colors.white, Icons.lock_person_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String t, Color bg, Color tc, IconData i) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, size: 10, color: tc), const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: tc)),
    ]),
  );

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), 
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)), 
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold))
  );

  Widget _buildDynamicFeaturedIsland() {
    return Container(
      margin: const EdgeInsets.only(top: 8), 
      padding: const EdgeInsets.all(16), 
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: List.generate(4, (i) => const CircleAvatar(
          radius: 25, backgroundColor: canvasGrey, 
          child: Icon(Icons.verified, color: primaryGreen, size: 20))
        )
      ),
    );
  }
}