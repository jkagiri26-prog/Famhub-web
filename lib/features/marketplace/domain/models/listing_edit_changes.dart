/// ============================================================
/// LISTING EDIT CHANGES (DOMAIN)
/// ============================================================
///
/// Typed, whitelisted description of the editable listing fields a seller
/// actually changed while editing a listing.
///
/// This object is intentionally narrow: it can only ever carry
///   title / description / price_per_unit / currency
/// It has no way to represent entity ids, stock ids, variant ids, unit ids,
/// location ids, images, status, promotion fields or timestamps — so the
/// presentation layer cannot accidentally mutate protected fields.
///
/// Only fields that differ from the original listing are non-null, so the
/// downstream payload always contains ONLY changed editable fields.
/// ============================================================
library;

import '../entities/listing.dart';

/// The editable metadata a seller changed on an existing listing.
class ListingEditChanges {
  /// New title. Null when the title was not changed.
  final String? title;

  /// Whether the description was part of this edit (including a clear).
  final bool descriptionChanged;

  /// New description. When [descriptionChanged] and null the seller cleared
  /// the description.
  final String? description;

  /// New price per unit (numeric). Null when the price was not changed.
  final double? pricePerUnit;

  /// New currency. Null when the currency was not changed.
  final String? currency;

  const ListingEditChanges({
    this.title,
    this.descriptionChanged = false,
    this.description,
    this.pricePerUnit,
    this.currency,
  });

  /// True when nothing was changed and no mutation should be attempted.
  bool get isEmpty =>
      title == null &&
      pricePerUnit == null &&
      currency == null &&
      !descriptionChanged;

  /// Computes the normalized set of changed editable fields between the
  /// original listing values and the seller's new values.
  ///
  /// Normalization rules:
  ///   - the title is trimmed before comparison
  ///   - a whitespace-only description is treated as an intentional clear
  ///     (null) and compared accordingly
  ///   - the price is compared numerically, never as a formatted string
  ///   - the currency is compared as-is
  static ListingEditChanges diff({
    required Listing original,
    required String title,
    required String? description,
    required double pricePerUnit,
    required String currency,
  }) {
    final normalizedTitle = title.trim();
    final rawDescription = description?.trim() ?? '';
    final effectiveDescription = rawDescription.isEmpty ? null : rawDescription;

    final titleChanged = normalizedTitle != original.title;
    final descriptionChanged = effectiveDescription != original.description;
    final priceChanged = pricePerUnit != original.pricePerUnit;
    final currencyChanged = currency != original.currency;

    return ListingEditChanges(
      title: titleChanged ? normalizedTitle : null,
      descriptionChanged: descriptionChanged,
      description: descriptionChanged ? effectiveDescription : null,
      pricePerUnit: priceChanged ? pricePerUnit : null,
      currency: currencyChanged ? currency : null,
    );
  }
}
