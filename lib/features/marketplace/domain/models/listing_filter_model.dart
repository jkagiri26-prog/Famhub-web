/// ============================================================
/// LISTING FILTER MODEL
/// ============================================================
///
/// Non-domain model for marketplace listing filter criteria.
/// Used in presentation layer for search and filter state.
/// ============================================================
library;

class ListingFilterModel {
  final String category;
  final String searchQuery;
  final String sortBy;

  const ListingFilterModel({
    this.category = 'ALL',
    this.searchQuery = '',
    this.sortBy = 'newest',
  });

  bool get hasActiveFilters =>
      category != 'ALL' || searchQuery.isNotEmpty;

  ListingFilterModel copyWith({
    String? category,
    String? searchQuery,
    String? sortBy,
  }) {
    return ListingFilterModel(
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
