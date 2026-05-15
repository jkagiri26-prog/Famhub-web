import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_service_provider.dart';

class RolePermissionEditor extends ConsumerStatefulWidget {
  const RolePermissionEditor({super.key});

  @override
  ConsumerState<RolePermissionEditor> createState() =>
      _RolePermissionEditorState();
}

class _RolePermissionEditorState
    extends ConsumerState<RolePermissionEditor> {
  final TextEditingController roleController =
      TextEditingController();

  final TextEditingController permissionController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    final adminService = ref.watch(adminServiceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                labelText: 'Role',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: permissionController,
              decoration: const InputDecoration(
                labelText: 'Permission Prefix',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await adminService.updateRolePermission(
                  roleController.text.trim(),
                  permissionController.text.trim(),
                );
              },
              child: const Text('Update Permission'),
            ),
          ],
        ),
      ),
    );
  }
}