/// ============================================================
/// ATTRIBUTE TYPE ENUM
/// ============================================================
///
/// Supported attribute types for dynamic activity forms.
/// Each type maps to a specific input widget in the form renderer.
/// ============================================================
library;

/// The type of an activity template attribute.
enum AttributeType {
  /// Single-line text input
  text,

  /// Numeric input (integer or decimal)
  number,

  /// Yes/No toggle
  boolean,

  /// Date picker
  date,

  /// Time picker
  time,

  /// Dropdown single-select
  select,

  /// Multi-select dropdown
  multiSelect,

  /// Multi-line text area
  textArea,

  /// Location / GPS coordinate picker
  location,

  /// Camera / photo upload
  photo;

  /// Human-readable display name for the attribute type.
  String get displayName {
    switch (this) {
      case AttributeType.text:
        return 'Text';
      case AttributeType.number:
        return 'Number';
      case AttributeType.boolean:
        return 'Yes/No';
      case AttributeType.date:
        return 'Date';
      case AttributeType.time:
        return 'Time';
      case AttributeType.select:
        return 'Dropdown';
      case AttributeType.multiSelect:
        return 'Multi-Select';
      case AttributeType.textArea:
        return 'Long Text';
      case AttributeType.location:
        return 'Location';
      case AttributeType.photo:
        return 'Photo';
    }
  }
}
