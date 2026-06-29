/// ============================================================
/// TEMPLATE ATTRIBUTE MODEL
/// ============================================================
///
/// Represents an attribute/field rule from activity_attribute_rules.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/attribute_type.dart';

/// An attribute definition within an activity template.
class TemplateAttribute {
  final String id;
  final String name;
  final String label;
  final AttributeType type;
  final bool isRequired;
  final String? defaultValue;
  final List<String>? options;
  final String? unit;
  final double? min;
  final double? max;
  final String? validationRule;
  final int sortOrder;

  const TemplateAttribute({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
    this.options,
    this.unit,
    this.min,
    this.max,
    this.validationRule,
    this.sortOrder = 0,
  });
}

