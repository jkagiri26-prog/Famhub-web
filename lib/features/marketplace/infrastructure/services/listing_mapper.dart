import '../../domain/entities/listing.dart';

class ListingMapper {
  static Listing fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  static Map<String, dynamic> toJson(Listing listing) {
    return {
      'id': listing.id,
      'title': listing.title,
      'price': listing.price,
      'unit': listing.unit,
      'images': listing.images,
      'created_at': listing.createdAt.toIso8601String(),
    };
  }
}