import 'package:flutter/material.dart';
import 'auth_page.dart'; // navigate to auth flow

class VisitorHomePage extends StatefulWidget {
  const VisitorHomePage({super.key});

  @override
  _VisitorHomePageState createState() => _VisitorHomePageState();
}

class _VisitorHomePageState extends State<VisitorHomePage> {
  final List<String> carouselImages = [
    'assets/images/farm1.png',
    'assets/images/farm2.png',
    'assets/images/farm3.png',
  ];

  int currentIndex = 0;

  String _getImageTitle(int index) {
    switch (index) {
      case 0:
        return "Sustainable Farming";
      case 1:
        return "Fresh Produce Market";
      case 2:
        return "Modern Agriculture";
      default:
        return "Farm Life";
    }
  }

  Widget moduleCard(String title, String emoji, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: color,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            child: Column(
              children: [
                // ---------------- Hero Section ----------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[700]!, Colors.green[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.agriculture_rounded, size: 80, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        "Welcome to Sandbox 👩‍🌾👨‍🌾",
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Connecting farmers, traders, and stakeholders.\nDiscover, trade, and grow your business.",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AuthPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green[700],
                            textStyle:
                                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text("Login / Sign Up"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- Carousel / Highlights ----------------
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: carouselImages.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[300], // Fallback color
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Try to load the asset image
                              Image.asset(
                                carouselImages[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to colored container if image fails
                                  return Container(
                                    color: [Colors.green[300], Colors.blue[300], Colors.orange[300]][index % 3],
                                    child: Center(
                                      child: Text(
                                        _getImageTitle(index),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Overlay gradient and text
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _getImageTitle(index),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    carouselImages.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: currentIndex == index ? 12 : 8,
                      height: currentIndex == index ? 12 : 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentIndex == index
                            ? Colors.green[700]
                            : Colors.green[200],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- Modules / Features ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: moduleCard("Marketplace", "🛒", Colors.orange[700]!)),
                                const SizedBox(width: 12),
                                Expanded(child: moduleCard("Farm Guides", "📚", Colors.blue[700]!)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: moduleCard("Smart Farm", "💧", Colors.green[700]!)),
                                const SizedBox(width: 12),
                                Expanded(child: moduleCard("Agri-Tech", "🖥️", Colors.purple[700]!)),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            moduleCard("Marketplace", "🛒", Colors.orange[700]!),
                            moduleCard("Farm Guides", "📚", Colors.blue[700]!),
                            moduleCard("Smart Farm", "💧", Colors.green[700]!),
                            moduleCard("Agri-Tech", "🖥️", Colors.purple[700]!),
                          ],
                        ),
                ),

                const SizedBox(height: 32),

                // ---------------- Call to Action ----------------
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Join thousands of farmers and traders today!",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AuthPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green[700],
                            textStyle:
                                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text("Sign Up Now"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
