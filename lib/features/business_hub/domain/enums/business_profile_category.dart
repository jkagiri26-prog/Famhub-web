/// ============================================================
/// BUSINESS PROFILE CATEGORY (DOMAIN)
/// ============================================================
///
/// Product-facing business categories used by the Trader first-use
/// "Create your business" flow.
///
/// `commerce.business_profiles.entity_type` only accepts:
///   individual | company | agrovet | cooperative | trader
///
/// Several product categories (aggregator, processor/factory, service
/// provider, other) have no dedicated database value, so they map to the
/// closest supported value (`company`) and keep their real product
/// classification in the existing `metadata` JSONB under
/// `business_category`.
///
/// Schema source: docs/Backend schemas/commerce schema.md
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

enum BusinessProfileCategory {
  trader(
    machineValue: 'trader',
    label: 'Trader',
    examples:
        'Mama mboga, grain trader, produce trader, '
        'general produce buyer/seller',
    dbEntityType: 'trader',
  ),
  agrovetInputSupplier(
    machineValue: 'agrovet_input_supplier',
    label: 'Agrovet / Input Supplier',
    examples:
        'Agrovet, seed seller, fertilizer seller, farm tools, '
        'agricultural inputs',
    dbEntityType: 'agrovet',
  ),
  aggregator(
    machineValue: 'aggregator',
    label: 'Aggregator',
    examples: 'Produce collection, farmer aggregation, buying centre',
    dbEntityType: 'company',
  ),
  processorFactory(
    machineValue: 'processor_factory',
    label: 'Processor / Factory',
    examples: 'Mill, dairy processor, juice processor, food factory',
    dbEntityType: 'company',
  ),
  serviceProvider(
    machineValue: 'service_provider',
    label: 'Service Provider',
    examples: 'Farm services, transport, labour, machinery services',
    dbEntityType: 'company',
  ),
  cooperative(
    machineValue: 'cooperative',
    label: 'Cooperative',
    examples:
        'Farmer cooperative, dairy cooperative, '
        'savings/marketing cooperative',
    dbEntityType: 'cooperative',
  ),
  other(
    machineValue: 'other',
    label: 'Other',
    examples: 'Something else',
    dbEntityType: 'company',
  );

  /// Stable, machine-readable value persisted in `metadata.business_category`.
  final String machineValue;

  /// Human-friendly product-facing label shown in the UI.
  final String label;

  /// Explanatory examples shown under the selected category. These are
  /// guidance only — they are never selectable as separate business types.
  final String examples;

  /// Value sent to `commerce.business_profiles.entity_type`. Must be one of
  /// the database check-constraint values.
  final String dbEntityType;

  const BusinessProfileCategory({
    required this.machineValue,
    required this.label,
    required this.examples,
    required this.dbEntityType,
  });
}
