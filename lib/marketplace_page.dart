import 'dart:async';
import 'package:flutter/material.dart';

/// FAMHUB Module: Marketplace (Final Production Version)
/// Features: Lazy Loading, AI-Mediated Navigation, Performance Isolation.
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
  
  // Theme Constants
  static const Color primaryGreen = Color(0xFF1B5E20); 
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
          // RepaintBoundary isolates carousel animations from the rest of the list
          RepaintBoundary(child: _buildTripleHeader()),
          _buildSearchAndFilterArea(),
          Expanded(
            child: ListView(
              cacheExtent: 1000, 
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDynamicFeaturedIsland(),
                
                // Segmented Display Logic
                if (_activeTab == "ALL" || _activeTab == "LIVESTOCK")
                  _buildSubcategoryIsland("LIVESTOCK", [
                    {"n": "Dairy Cow (Friesian)", "d": "1.2km", "p": "KSh 85,000"}, 
                    {"n": "Beef Bull", "d": "4.5km", "p": "KSh 110,000"},
                    {"n": "Dairy Goat", "d": "2.1km", "p": "KSh 12,500"}
                  ]),
                
                if (_activeTab == "ALL" || _activeTab == "CROPS")
                  _buildSubcategoryIsland("CROPS & PRODUCE", [
                    {"n": "Yellow Maize (90kg)", "d": "0.8km", "p": "KSh 3,200"}, 
                    {"n": "Red Onions", "d": "12km", "p": "KSh 150/kg"}
                  ]),
                
                const SizedBox(height: 100), // Navigation buffer
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildTripleHeader() {
    return Container(
      height: 110,
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
        gradient: const LinearGradient(colors: [primaryGreen, Color(0xFF2E7D32)]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
          SizedBox(height: 4),
          Text("SELL\nNOW", textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
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
          final List<Color> colors = [Colors.blue.shade800, Colors.orange.shade800, Colors.purple.shade800];
          return Container(
            color: colors[index],
            child: const Center(child: Icon(Icons.local_offer, color: Colors.white24, size: 35)),
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
          color: _currentAdIndex == 0 ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6)
        ),
        child: Center(
          child: Text(_currentAdIndex == 0 ? "TOYOTA\nAGRI" : "PANNAR\nSEEDS",
            textAlign: TextAlign.center, 
            style: TextStyle(
              color: _currentAdIndex == 0 ? Colors.blue.shade900 : Colors.orange.shade900, 
              fontSize: 9, fontWeight: FontWeight.w900)
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
          Container(
            height: 38,
            decoration: BoxDecoration(color: canvasGrey, borderRadius: BorderRadius.circular(4)),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search items near you...", 
                prefixIcon: Icon(Icons.search, size: 16), 
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8)
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                    margin: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(
                      color: isMe ? Colors.orange : Colors.transparent, width: 2))),
                    child: Text(_filterTabs[i], style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, 
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: canvasGrey))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.orange),
              ],
            ),
          ),
          SizedBox(
            height: 255, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) => _buildProductCard(items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, String> item) {
    return GestureDetector(
      onTap: () {
        // NAVIGATE TO PRODUCT DETAILS (Mediation Bridge)
        // Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsPage(product: item)));
      },
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4), 
          border: Border.all(color: canvasGrey)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(height: 100, width: double.infinity, color: canvasGrey, 
                  child: const Icon(Icons.image_outlined, color: Colors.black12, size: 30)),
                Positioned(top: 5, left: 5, child: _badge(item['d']!, Colors.black87)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['n']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
                  Text(item['p']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primaryGreen)),
                  const SizedBox(height: 8),
                  _actionBtn("AI CHAT SELLER", primaryGreen.withOpacity(0.08), primaryGreen, Icons.auto_awesome),
                  const SizedBox(height: 6),
                  _actionBtn("LOCKED CONTACT", Colors.grey.shade900, Colors.white, Icons.lock_person_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String t, Color bg, Color tc, IconData i) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
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
          child: Icon(Icons.verified_user_outlined, color: primaryGreen, size: 20))
        )
      ),
    );
  }
}