/// ============================================================
/// AGRI CONNECT — CREATE DISCUSSION PAGE
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../application/providers/discussion_provider.dart';
import '../format.dart';
import 'discussion_details_page.dart';

class CreateDiscussionPage extends ConsumerStatefulWidget {
  final String communityId;

  const CreateDiscussionPage({super.key, required this.communityId});

  @override
  ConsumerState<CreateDiscussionPage> createState() =>
      _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends ConsumerState<CreateDiscussionPage> {
  final _titleController = TextEditingController();
  DiscussionType _type = DiscussionType.discussion;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final discussion = await ref
          .read(discussionControllerProvider.notifier)
          .createDiscussion(
            communityId: widget.communityId,
            title: title,
            type: _type,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DiscussionDetailsPage(discussionId: discussion.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create discussion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('New Discussion'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'What would you like to discuss?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in DiscussionType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Discussion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
