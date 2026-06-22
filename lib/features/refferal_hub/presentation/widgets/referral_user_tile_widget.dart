import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

class ReferralUserTileWidget extends StatelessWidget {
  final String name;
  final String joinedDate;
  final bool isVerified;

  const ReferralUserTileWidget({
    super.key,
    required this.name,
    required this.joinedDate,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name[0]),
        ),
        title: Text(name),
        subtitle: Text('Joined $joinedDate'),
        trailing: Text(
          isVerified ? 'Verified' : 'Pending',
        ),
      ),
    );
  }
}
