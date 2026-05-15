import 'package:flutter/material.dart';

class RoleSelectorWidget extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const RoleSelectorWidget({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const List<String> roles = [
    'Farmer',
    'Trader',
    'Buyer',
    'Agrovet',
    'Cooperative',
  ];

  @override
  Widget build(BuildContext context) {
    final Color primary =
        Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          roles.map((role) {
            final bool isSelected =
                selected == role;

            return GestureDetector(
              onTap: () {
                onChanged(role);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? primary.withOpacity(
                            0.08,
                          )
                          : Colors.white,
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? primary
                            : Colors.grey
                                .shade300,
                  ),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                    color:
                        isSelected
                            ? primary
                            : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}