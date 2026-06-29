import 'package:flutter/material.dart';

import 'package:famhub_app/features/farm_management/domain/enums/attribute_type.dart';
import 'package:famhub_app/features/farm_management/domain/models/template_attribute.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/date_picker_field.dart';

/// Renders dynamic forms from template attributes.
class DynamicActivityFormRenderer extends StatelessWidget {
  final List<TemplateAttribute> attributes;
  final Map<String, dynamic> values;
  final Function(String key, dynamic value) onValueChanged;
  final List<String>? onlyAttributes;

  const DynamicActivityFormRenderer({
    super.key,
    required this.attributes,
    required this.values,
    required this.onValueChanged,
    this.onlyAttributes,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = onlyAttributes != null
        ? attributes.where((a) => onlyAttributes!.contains(a.name)).toList()
        : attributes;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No attributes defined for this activity type.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final sorted = List<TemplateAttribute>.from(filtered)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.map((attr) => _buildField(context, attr)).toList(),
    );
  }

  Widget _buildField(BuildContext context, TemplateAttribute attr) {
    final currentValue = values[attr.name];

    switch (attr.type) {
      case AttributeType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue as String? ?? attr.defaultValue,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              helperText: attr.unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => onValueChanged(attr.name, val),
            validator: attr.isRequired ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          ),
        );

      case AttributeType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue?.toString() ?? attr.defaultValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              helperText: attr.unit,
              suffixText: attr.unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => onValueChanged(attr.name, double.tryParse(val)),
            validator: (v) {
              if (attr.isRequired && (v == null || v.isEmpty)) return 'Required';
              final num = double.tryParse(v ?? '');
              if (num != null) {
                if (attr.min != null && num < attr.min!) return 'Min: ${attr.min}';
                if (attr.max != null && num > attr.max!) return 'Max: ${attr.max}';
              }
              return null;
            },
          ),
        );

      case AttributeType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SwitchListTile(
            title: Text('${attr.label}${attr.isRequired ? ' *' : ''}'),
            value: currentValue as bool? ?? false,
            onChanged: (val) => onValueChanged(attr.name, val),
            contentPadding: EdgeInsets.zero,
          ),
        );

      case AttributeType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DatePickerField(
            label: attr.label,
            isRequired: attr.isRequired,
            initialValue: currentValue as DateTime?,
            onChanged: (val) => onValueChanged(attr.name, val),
          ),
        );

      case AttributeType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            value: currentValue as String? ?? attr.defaultValue,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              if (!attr.isRequired)
                const DropdownMenuItem(value: null, child: Text('Select...')),
              ...(attr.options ?? []).map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt),
              )),
            ],
            onChanged: (val) => onValueChanged(attr.name, val),
            validator: attr.isRequired ? (v) => v == null ? 'Required' : null : null,
          ),
        );

      case AttributeType.textArea:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: currentValue as String? ?? attr.defaultValue,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '${attr.label}${attr.isRequired ? ' *' : ''}',
              hintText: 'Enter ${attr.label.toLowerCase()}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (val) => onValueChanged(attr.name, val),
          ),
        );

      case AttributeType.time:
      case AttributeType.location:
      case AttributeType.multiSelect:
      case AttributeType.photo:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${attr.label} (${attr.type.displayName} input coming soon)',
            style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        );
    }
  }
}
