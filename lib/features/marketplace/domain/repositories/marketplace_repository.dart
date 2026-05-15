class MarketplaceRepository {
  final MarketplaceService service;

  MarketplaceRepository(this.service);

  Future<List<Listing>> fetchListings() async {
    final data = await service.getListings();
    return data.map((e) => ListingMapper.fromJson(e)).toList();
  }

  Future<void> createListing(Map payload) async {
    await service.createListing(payload);
  }
}