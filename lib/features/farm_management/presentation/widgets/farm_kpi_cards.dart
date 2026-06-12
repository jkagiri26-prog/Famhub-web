import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';

class FarmKpiCards extends StatelessWidget {
  final FarmDashboardSummary summary;

  const FarmKpiCards({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ['Production', summary.totalProduction.toString()],
      ['Sales', summary.totalSales.toStringAsFixed(0)],
      ['Expenses', summary.totalExpenses.toStringAsFixed(0)],
      ['Yield', summary.totalYield.toString()],
      ['Stock Value', summary.stockValue.toStringAsFixed(0)],
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) {
        return SizedBox(
          width: 220,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item[0],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item[1],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

