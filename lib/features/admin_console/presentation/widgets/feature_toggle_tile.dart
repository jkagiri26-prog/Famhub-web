import 'package:flutter/material.dart';

class FeatureToggleTile extends StatelessWidget {
  final String featureKey;
  final bool isEnabled;

  const FeatureToggleTile({
    super.key,
    required this.featureKey,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(_formatFeatureName(featureKey)),
        subtitle: Text(featureKey),
        value: isEnabled,
        onChanged: (value) {
          // TODO: Implement feature toggle logic
        },
      ),
    );
  }

  String _formatFeatureName(String key) {
    return key
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }
}