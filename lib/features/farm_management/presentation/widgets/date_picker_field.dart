import 'package:flutter/material.dart';

/// Date picker field widget for dynamic forms.
class DatePickerField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final DateTime? initialValue;
  final ValueChanged<DateTime> onChanged;

  const DatePickerField({
    super.key,
    required this.label,
    required this.isRequired,
    this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialValue ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (date != null) onChanged(date);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          initialValue != null
              ? '${initialValue!.day}/${initialValue!.month}/${initialValue!.year}'
              : 'Select date',
        ),
      ),
    );
  }
}

