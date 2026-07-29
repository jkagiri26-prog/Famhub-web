/// ============================================================
/// AREA VALIDATION SERVICE (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Enforces the FAMHUB area validation policy:
///   "The sum of all field areas must never exceed the total farm area."
///
/// Validation scenarios:
///   - Creating a new field
///   - Updating an existing field's acreage
///   - Creating a new farm with default field
///
/// Example:
///   Farm Area = 10 Acres
///   Valid: Main Field = 4 + Block A = 3 + Block B = 3 = 10 ✅
///   Invalid: Main Field = 5 + Block A = 4 + Block B = 3 = 12 ❌
/// ============================================================
library;

import 'dart:math';

/// Result of area validation
class AreaValidationResult {
  final bool isValid;
  final String? message;
  /// The total area currently occupied by fields
  final double currentOccupied;
  /// The remaining area available for allocation
  final double remainingArea;
  /// The farm's total area
  final double farmArea;
  /// The requested area that was validated
  final double? requestedArea;

  const AreaValidationResult({
    required this.isValid,
    this.message,
    required this.currentOccupied,
    required this.remainingArea,
    required this.farmArea,
    this.requestedArea,
  });
}

/// Domain service for validating field area allocations.
///
/// Ensures the sum of all field areas never exceeds the farm's total area.
/// This is called BEFORE persisting any field creation or update.
class AreaValidationService {
  const AreaValidationService();

  /// Validate that a new field's acreage (or an update to an existing field's acreage)
  /// does not exceed the farm's available remaining area.
  ///
  /// [farmArea] - The total area of the farm
  /// [currentFieldsArea] - The sum of ALL existing field areas
  /// [newFieldArea] - The acreage of the field being created or updated
  ///
  /// Returns [AreaValidationResult] with validity and message.
  AreaValidationResult validateFieldArea({
    required double farmArea,
    required double currentFieldsArea,
    double? newFieldArea,
  }) {
    // If no specific area is being validated (e.g., area is null/optional),
    // check if the current allocation is valid
    if (newFieldArea == null || newFieldArea <= 0) {
      if (currentFieldsArea > farmArea) {
        return AreaValidationResult(
          isValid: false,
          message: 'Field areas (${_formatArea(currentFieldsArea)} ha) exceed farm area (${_formatArea(farmArea)} ha). Reduce other field areas first.',
          currentOccupied: currentFieldsArea,
          remainingArea: max(0.0, farmArea - currentFieldsArea),
          farmArea: farmArea,
        );
      }
      return AreaValidationResult(
        isValid: true,
        currentOccupied: currentFieldsArea,
        remainingArea: max(0.0, farmArea - currentFieldsArea),
        farmArea: farmArea,
      );
    }

    // Calculate what the total would be with the new/updated field
    final potentialTotal = currentFieldsArea + newFieldArea;
    final remaining = farmArea - potentialTotal;

    if (potentialTotal > farmArea) {
      final available = max(0.0, farmArea - currentFieldsArea);
      return AreaValidationResult(
        isValid: false,
        message: 'Total field area (${_formatArea(potentialTotal)} ha) would exceed farm area (${_formatArea(farmArea)} ha). '
            'Available remaining area: ${_formatArea(available)} ha.',
        currentOccupied: currentFieldsArea,
        remainingArea: available,
        farmArea: farmArea,
        requestedArea: newFieldArea,
      );
    }

    return AreaValidationResult(
      isValid: true,
      currentOccupied: currentFieldsArea,
      remainingArea: remaining,
      farmArea: farmArea,
      requestedArea: newFieldArea,
    );
  }

  /// Validate the total area of all fields does not exceed the farm area.
  /// Returns null if valid, or an error message string if invalid.
  String? validateTotalFieldAreas({
    required double farmArea,
    required double totalFieldsArea,
  }) {
    if (totalFieldsArea > farmArea) {
      return 'Total field area (${_formatArea(totalFieldsArea)} ha) exceeds farm area (${_formatArea(farmArea)} ha). Please reduce field areas.';
    }
    return null;
  }

  /// Format area value for display
  String _formatArea(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}