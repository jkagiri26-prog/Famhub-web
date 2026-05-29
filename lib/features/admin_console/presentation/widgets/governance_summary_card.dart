import 'package:flutter/material.dart';

class GovernanceSummaryCards extends StatelessWidget {
  const GovernanceSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          title: 'Active Modules',
          value: '12',
        ),
        _SummaryCard(
          title: 'Premium Features',
          value: '8',
        ),
        _SummaryCard(
          title: 'Maintenance Mode',
          value: '2',
        ),
        _SummaryCard(
          title: 'Locked Features',
          value: '5',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
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
  }
}