class _ModulesPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModuleCard(
          title: "Marketplace",
          description: "Buy & sell farm products",
        ),
        _ModuleCard(
          title: "AgriTech",
          description: "AI insights for your farm",
        ),
      ],
    );
  }
}