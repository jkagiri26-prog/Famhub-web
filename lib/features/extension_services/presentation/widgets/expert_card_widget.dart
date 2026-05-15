import 'package:flutter/material.dart';

import '../../../../../shared/layout/section_container_widget.dart';

class ExpertCardWidget extends StatelessWidget {
  final String name;
  final String specialty;
  final String status;
  final String imageUrl;

  const ExpertCardWidget({
    super.key,
    required this.name,
    required this.specialty,
    required this.status,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final bool isOnline = status.toLowerCase() == 'online';

    return SectionContainerWidget(
      child: Row(
        children: [
          /// PROFILE IMAGE
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(imageUrl),
            backgroundColor: Colors.grey.shade200,
          ),

          const SizedBox(width: 14),

          /// DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color:
                          isOnline
                              ? primary
                              : Colors.orange.shade700,
                    ),

                    const SizedBox(width: 6),

                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isOnline
                                ? primary
                                : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// ACTION
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }
}