/// One public product specification resolved from the canonical Core
/// product-attribute tables for a listing's variant/item.
///
/// This is a read-only presentation model; it is not a second attribute
/// system. Names, values and units come from `core.attribute_registry` and
/// the existing item/variant attribute rows.
class ListingSpecification {
  final String name;
  final String value;

  const ListingSpecification({required this.name, required this.value});
}
