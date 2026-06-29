/// ============================================================
/// CROP STATUS ENUM
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents the lifecycle status of a crop.
/// Maps to the `crop_status` enum in the database.
/// ============================================================
library;

/// Status of a crop within a farm field.
enum CropStatus {
  /// Crop has been planted, not yet emerged
  planted,

  /// Crop is actively growing in the field
  growing,

  /// Crop has been harvested
  harvested,

  /// Crop failed (disease, drought, pests, etc.)
  failed,
}
