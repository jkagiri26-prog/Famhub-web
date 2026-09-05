import 'package:flutter/material.dart';

import '../../domain/entities/listing.dart';
import '../../domain/enums/listing_status.dart';

/// Reusable listing status badge.
/// Shows colored pill with status text.
class ListingStatusBadge extends StatelessWidget {
  final ListingStatus status;

  const ListingStatusBadge({super.key, required this.status});

  Color get _color => switch (status) {
    ListingStatus.active => Colors.green,
    ListingStatus.draft => Colors.grey,
    ListingStatus.paused => Colors.orange,
    ListingStatus.soldOut => Colors.red,
    ListingStatus.archived => Colors.grey,
    ListingStatus.inactive => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.value.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
