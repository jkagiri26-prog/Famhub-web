import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class ReferralLeaderboardTileWidget extends StatelessWidget {
  final String name;
  final int rank;
  final int referrals;
  final bool isCurrentUser;

  const ReferralLeaderboardTileWidget({
    super.key,
    required this.name,
    required this.rank,
    required this.referrals,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: ListTile(
        leading: Text(
          '#$rank',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        title: Text(name),
        trailing: Text(
          '$referrals referrals',
        ),
      ),
    );
  }
}
