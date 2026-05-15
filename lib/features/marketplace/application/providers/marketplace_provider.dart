final marketplaceProvider =
    StateNotifierProvider<MarketplaceController, List<Listing>>((ref) {
  return MarketplaceController(
    MarketplaceRepository(MarketplaceService()),
  );
});

class MarketplaceController extends StateNotifier<List<Listing>> {
  final MarketplaceRepository repo;

  MarketplaceController(this.repo) : super([]);

  Future<void> load() async {
    state = await repo.fetchListings();
  }
}