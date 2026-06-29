/// ============================================================
/// MARKETPLACE — APPLICATION STATE
/// ============================================================
///
/// State classes for marketplace module orchestration.
/// Contains view states, filter states, and page states.
/// ============================================================
library;

/// Represents the current marketplace view state.
enum MarketplaceViewState {
  loading,
  ready,
  error,
  empty,
}

/// Represents active filter selections for listing queries.
class MarketplaceFilterState {
  final String category;
  final String searchQuery;
  final String sortBy;

  const MarketplaceFilterState({
    this.category = 'ALL',
    this.searchQuery = '',
    this.sortBy = 'newest',
  });

  MarketplaceFilterState copyWith({
    String? category,
    String? searchQuery,
    String? sortBy,
  }) {
    return MarketplaceFilterState(
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
