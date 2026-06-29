import '../../domain/entities/listing.dart';
import '../../domain/enums/listing_status.dart';

class ListingMapper {
  static Listing fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      location: json['location']?.toString(),
      sellerId: json['seller_id']?.toString(),
      sellerName: json['seller_name']?.toString(),
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      availableQuantity: (json['available_quantity'] as num?)?.toDouble() ?? 0,
      soldQuantity: (json['sold_quantity'] as num?)?.toDouble() ?? 0,
      reservedQuantity: (json['reserved_quantity'] as num?)?.toDouble() ?? 0,
      status: ListingStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  static Map<String, dynamic> toJson(Listing listing) {
    return {
      'id': listing.id,
      'title': listing.title,
      'description': listing.description,
      'price': listing.price,
      'unit': listing.unit,
      'images': listing.images,
      'location': listing.location,
      'seller_id': listing.sellerId,
      'seller_name': listing.sellerName,
      'seller_rating': listing.sellerRating,
      'available_quantity': listing.availableQuantity,
      'sold_quantity': listing.soldQuantity,
      'reserved_quantity': listing.reservedQuantity,
      'status': listing.status.value,
      'created_at': listing.createdAt.toIso8601String(),
    };
  }
}