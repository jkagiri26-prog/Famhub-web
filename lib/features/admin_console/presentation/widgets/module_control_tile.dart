import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_service_provider.dart';

class ModuleControlTile extends ConsumerWidget {
  final String moduleKey;
  final bool isEnabled;

  const ModuleControlTile({
    super.key,
    required this.moduleKey,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminService = ref.watch(adminServiceProvider);

    return Card(
      child: SwitchListTile(
        title: Text(moduleKey),
        subtitle: const Text('Enable / Disable module access'),
        value: isEnabled,
        onChanged: (value) async {
          await adminService.toggleModule(
            moduleKey: moduleKey,
            enabled: value,
          );
        },
      ),
    );
  }
}