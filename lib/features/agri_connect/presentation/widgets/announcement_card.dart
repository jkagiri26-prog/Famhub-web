/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT CARD
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../domain/entities/announcement.dart';
import '../format.dart';

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementCard({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (announcement.isPinned) ...[
                Icon(Icons.push_pin, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              Text(
                announcement.type.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            announcement.body,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.orange.shade900.withValues(alpha: 0.85),
            ),
          ),
          if (announcement.expiresAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Until ${agriFullDate(announcement.expiresAt)}',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
