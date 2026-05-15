class Listing {
  final String id;
  final String title;
  final double price;
  final String unit;
  final List<String> images;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    required this.price,
    required this.unit,
    required this.images,
    required this.createdAt,
  });
}