import 'dart:async';

class MarketplaceUIController {
  Timer? carouselTimer;

  int carouselIndex = 0;
  int adIndex = 0;
  String activeTab = "ALL";

  final List<String> tabs = const [
    "ALL",
    "LIVESTOCK",
    "CROPS",
    "INPUTS",
    "MACHINERY",
    "SERVICES"
  ];

  void start(Function updateUI) {
    carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      carouselIndex = (carouselIndex + 1) % 3;
      if (timer.tick % 2 == 0) {
        adIndex = (adIndex + 1) % 2;
      }
      updateUI();
    });
  }

  void dispose() {
    carouselTimer?.cancel();
  }

  void setTab(String tab, Function updateUI) {
    activeTab = tab;
    updateUI();
  }
}