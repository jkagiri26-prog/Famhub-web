/// ============================================================
/// AGRI CONNECT — REPORT SHEET
/// ============================================================
///
/// Shared report flow. Submits via the existing moderation controller.
/// Backend authorization + immutable-report trigger remain authoritative.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/safety_enums.dart';
import '../../application/providers/moderation_provider.dart';

const List<String> kReportReasons = [
  'Spam or advertising',
  'Harassment or bullying',
  'Inappropriate content',
  'Misinformation',
  'Other',
];

Future<void> showAgriReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetType targetType,
  required String targetId,
}) {
  final reasonController = TextEditingController();
  String selected = kReportReasons.first;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report content',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                for (final reason in kReportReasons)
                  RadioListTile<String>(
                    value: reason,
                    groupValue: selected,
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add details (optional)',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(moderationControllerProvider.notifier)
                            .submitReport(
                              targetType: targetType,
                              targetId: targetId,
                              reason: selected,
                              description: reasonController.text.trim(),
                            );
                        if (context.mounted) Navigator.of(context).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted. Thank you.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not report: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
