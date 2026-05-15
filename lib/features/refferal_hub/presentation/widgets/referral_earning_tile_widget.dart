import 'package:flutter/material.dart';

import '../../../../shared/widgets/layout/section_container_widget.dart';

class ReferralEarningTileWidget extends StatelessWidget {
  final String title;
  final String amount;
  final String date;
  final bool isDebit;

  const ReferralEarningTileWidget({
    super.key,
    required this.title,
    required this.amount,
    required this.date,
    required this.isDebit,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      child: ListTile(
        leading: Icon(
          isDebit ? Icons.arrow_outward : Icons.south_west,
        ),
        title: Text(title),
        subtitle: Text(date),
        trailing: Text(
          amount,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}