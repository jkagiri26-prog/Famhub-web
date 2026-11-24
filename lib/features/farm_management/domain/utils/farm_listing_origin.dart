import '../entities/farm_entity.dart';

/// The canonical seller entity for a farm-context Marketplace listing.
///
/// `FarmEntity.id` is the farm record (`farm_management.farms.id`) and must
/// never be used as `marketplace.listings.entity_id`. The owning entity is
/// [FarmEntity.entityId].
String? farmListingSellerEntityId(FarmEntity? farm) => farm?.entityId;

/// The listing location derived from the same selected farm record.
String? farmListingLocationId(FarmEntity? farm) =>
    farm?.wardId ?? farm?.subCountyId ?? farm?.countyId;
