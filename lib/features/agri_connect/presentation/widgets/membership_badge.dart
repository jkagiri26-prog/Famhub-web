/// ============================================================
/// AGRI CONNECT — MEMBERSHIP / ROLE BADGE
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../domain/enums/community_enums.dart';
import '../format.dart';

class MembershipBadge extends StatelessWidget {
  final MemberRole role;
  final MemberStatus status;
  final bool compact;

  const MembershipBadge({
    super.key,
    required this.role,
    this.status = MemberStatus.active,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status != MemberStatus.active) {
      return _chip(
        context,
        status.label,
        _statusColor(status),
        Icons.block_outlined,
      );
    }
    if (role == MemberRole.member) return const SizedBox.shrink();
    return _chip(context, role.label, _roleColor(role), Icons.shield_outlined);
  }

  Color _statusColor(MemberStatus status) => switch (status) {
    MemberStatus.pending => Colors.orange.shade700,
    MemberStatus.suspended => Colors.orange.shade700,
    MemberStatus.banned => Colors.red.shade700,
    MemberStatus.left => Colors.grey.shade600,
    MemberStatus.rejected => Colors.grey.shade600,
    MemberStatus.active => Colors.green.shade700,
  };

  Color _roleColor(MemberRole role) => switch (role) {
    MemberRole.owner => Colors.purple.shade700,
    MemberRole.admin => Colors.indigo.shade700,
    MemberRole.moderator => Colors.teal.shade700,
    MemberRole.member => Colors.grey.shade600,
  };

  Widget _chip(BuildContext context, String text, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
