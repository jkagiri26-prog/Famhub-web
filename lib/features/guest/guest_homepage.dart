class GuestHomePage extends StatelessWidget {
  const GuestHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          _HeroSection(),
          _ModulesPreview(),
          _CallToAction(),
        ],
      ),
    );
  }
}