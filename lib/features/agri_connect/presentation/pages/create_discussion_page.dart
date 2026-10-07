/// ============================================================
/// AGRI CONNECT — CREATE DISCUSSION PAGE
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../marketplace/infrastructure/services/listing_image_processing.dart';
import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../application/providers/discussion_provider.dart';
import '../format.dart';
import 'discussion_details_page.dart';

class CreateDiscussionPage extends ConsumerStatefulWidget {
  /// null → public forum discussion (no community).
  final String? communityId;

  const CreateDiscussionPage({super.key, this.communityId});

  @override
  ConsumerState<CreateDiscussionPage> createState() =>
      _CreateDiscussionPageState();
}

class _CreateDiscussionPageState extends ConsumerState<CreateDiscussionPage> {
  /// Hard cap for the image-attachment MVP.
  static const int _maxImages = 2;

  final _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ListingImageProcessingService _processor =
      const ListingImageProcessingService();

  DiscussionType _type = DiscussionType.discussion;

  /// Compressed (WebP, ≤2 MB) previews — these are exactly the bytes that
  /// get uploaded, so what the user sees is what gets posted.
  final List<Uint8List> _images = [];
  bool _picking = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _remaining => _maxImages - _images.length;

  Future<void> _pickImage() async {
    if (_picking || _remaining <= 0) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final prepared = await _processor.prepare(
        bytes: bytes,
        sourceName: file.name,
      );
      if (_images.length >= _maxImages) return;
      setState(() => _images.add(prepared.bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add photo: $e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  /// Local previews + the add tile. The add tile disappears at 2 images.
  Widget _imageArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _images.length; i++)
          Stack(
            key: ValueKey('agri_image_preview_$i'),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _images[i],
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_images.length < _maxImages)
          InkWell(
            onTap: _picking ? null : _pickImage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
              ),
              child: _picking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_a_photo_outlined,
                      color: cs.primary,
                      size: 22,
                    ),
            ),
          ),
      ],
    );
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
            images: List.of(_images),
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DiscussionDetailsPage(discussionId: discussion.id),
        ),
      );
    } on DiscussionAttachException catch (e) {
      // The discussion exists — navigate to it and explain the image failure.
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DiscussionDetailsPage(discussionId: e.discussion.id),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Discussion posted. Images could not be attached: ${e.cause}',
          ),
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
                hintText: widget.communityId == null
                    ? 'e.g. How can I control fall armyworm in maize?'
                    : 'What would you like to discuss?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.communityId == null
                  ? 'This will be shared in the public forum.'
                  : 'This will be shared with this community.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            Row(
              children: [
                Text(
                  'Photos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_images.length} / $_maxImages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _images.length >= _maxImages
                        ? Theme.of(context).colorScheme.tertiary
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _imageArea(context),
            const SizedBox(height: 6),
            Text(
              _images.length >= _maxImages
                  ? 'Maximum of 2 photos reached.'
                  : 'Up to 2 photos. Images are compressed before upload.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
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
