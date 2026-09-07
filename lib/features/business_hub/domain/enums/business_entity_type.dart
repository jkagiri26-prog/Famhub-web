/// ============================================================
/// BUSINESS ENTITY TYPE ENUM (DOMAIN)
/// ============================================================
///
/// Mirrors `core.entities.entity_type`:
///   farm | trading_company | service_provider | cooperative |
///   individual_pro | agrovet
///
/// Schema source: docs/Backend schemas/core schema.md
///
/// NOTE: Factories / processors / banks / SACCOs / MFIs / logistics
/// businesses do NOT have a dedicated `entity_type` value today; they
/// register as one of the supported commercial types (e.g.
/// `trading_company`, `service_provider`). Do NOT invent new enum
/// values — confirmed backend vocabulary is used as-is.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

enum BusinessEntityType {
  farm('farm', 'Farm'),
  tradingCompany('trading_company', 'Trading Company'),
  serviceProvider('service_provider', 'Service Provider'),
  cooperative('cooperative', 'Cooperative'),
  individualPro('individual_pro', 'Individual Professional'),
  agrovet('agrovet', 'Agrovet'),
  other('other', 'Other');

  /// Raw backend value in `core.entities.entity_type`.
  final String dbValue;

  /// Human-friendly display label.
  final String label;

  const BusinessEntityType(this.dbValue, this.label);

  /// Parse a raw `core.entities.entity_type` value. Unknown values map to
  /// [BusinessEntityType.other] so the UI never breaks on new backend rows.
  static BusinessEntityType fromDb(String? raw) {
    for (final type in values) {
      if (type.dbValue == raw) return type;
    }
    return BusinessEntityType.other;
  }
}
