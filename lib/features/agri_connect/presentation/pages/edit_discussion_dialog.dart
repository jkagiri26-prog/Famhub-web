/// ============================================================
/// AGRI CONNECT — EDIT DISCUSSION DIALOG
/// ============================================================
///
/// Title / type / image editing for an existing discussion. Field
/// conventions mirror CreateDiscussionPage; images reuse the existing
/// media infrastructure (upload_media / media_get_by_context / delete_media)
/// and the marketplace image-processing service for compression.
///
/// Pop result: [editDiscussionSaved] on full success, a
/// [DiscussionEditException] when the text saved but the images did not
/// fully complete, null on cancel. Total failures keep the dialog open
/// with an error so the draft is never lost.
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../marketplace/infrastructure/services/listing_image_processing.dart';
import '../../application/providers/agri_connect_providers.dart';
import '../../application/providers/discussion_provider.dart';
import '../../domain/entities/discussion.dart';
import '../../domain/enums/discussion_enums.dart';
import '../../infrastructure/data_sources/agri_connect_media.dart';

/// Pop value for a fully successful save.
const String editDiscussionSaved = 'saved';

class EditDiscussionDialog extends ConsumerStatefulWidget {
  final Discussion discussion;

  const EditDiscussionDialog({super.key, required this.discussion});

  @override
  ConsumerState<EditDiscussionDialog> createState() =>
      _EditDiscussionDialogState();
}

class _EditDiscussionDialogState extends ConsumerState<EditDiscussionDialog> {
  /// Backend limit: maximum 2 active media files per discussion.
  static const int _maxImages = 2;

  late final TextEditingController _titleController;
  late final List<String> _typeValues;
  late int _currentTypeIndex;

  /// Ids of existing images the author chose to keep — seeded from
  /// `metadata.media_file_ids` and only changed by an explicit remove, so
  /// a failed URL load can never empty the list.
  late final List<String> _retainedIds;

  /// Compressed (WebP, ≤2 MB) previews — exactly the bytes that upload.
  final List<Uint8List> _newImages = [];
  final Map<String, String> _existingUrls = {};

  final ImagePicker _picker = ImagePicker();
  final ListingImageProcessingService _processor =
      const ListingImageProcessingService();

  bool _loadingUrls = false;
  String? _urlError;
  bool _picking = false;
  bool _saving = false;

  int get _totalImages => _retainedIds.length + _newImages.length;
  Discussion get _discussion => widget.discussion;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _discussion.title);
    _typeValues = DiscussionType.values.map((e) => e.name).toList();
    _currentTypeIndex = _typeValues.indexWhere(
      (n) => n == _discussion.type.name,
    );
    if (_currentTypeIndex < 0) {
      _currentTypeIndex = 0;
    }
    _retainedIds = List.of(_discussion.mediaFileIds);
    if (_retainedIds.isNotEmpty) _loadExistingUrls();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Resolve signed URLs for the images already attached to the
  /// discussion through the existing authorization flow. A failure only
  /// shows an error — retained ids are never dropped.
  Future<void> _loadExistingUrls() async {
    setState(() {
      _loadingUrls = true;
      _urlError = null;
    });
    final media = ref.read(agriConnectMediaProvider);
    try {
      final entries = await media.fetchMediaEntries(
        context: AgriConnectMediaDataSource.discussionLookupContext,
        contextId: _discussion.id,
      );
      final resolved = <String, String>{};
      for (final entry in entries) {
        final id = entry['id'];
        if (id == null || !_retainedIds.contains(id)) continue;
        resolved[id] = await media.resolveDisplayUrl(entry);
      }
      if (!mounted) return;
      setState(() {
        _existingUrls.addAll(resolved);
        _loadingUrls = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUrls = false;
        _urlError = 'Could not load existing images: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    if (_picking || _totalImages >= _maxImages) return;
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
      if (_totalImages >= _maxImages) return;
      setState(() => _newImages.add(prepared.bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add photo: $e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(discussionControllerProvider.notifier)
          .editDiscussion(
            discussionId: _discussion.id,
            discussion: _discussion,
            title: title,
            discussionType: _typeValues[_currentTypeIndex],
            retainedMediaIds: _retainedIds.toSet(),
            newImages: List.of(_newImages),
          );
      if (!mounted) return;
      Navigator.of(context).pop(editDiscussionSaved);
    } on DiscussionEditException catch (e) {
      // Text saved, images incomplete — close and let the caller explain.
      if (!mounted) return;
      Navigator.of(context).pop(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save changes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Edit Discussion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _typeValues[_currentTypeIndex],
              decoration: const InputDecoration(labelText: 'Type'),
              items: _typeValues
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(
                () =>
                    _currentTypeIndex = _typeValues.indexWhere((n) => n == val),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Images  $_totalImages/$_maxImages',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                if (_loadingUrls) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (_urlError != null) ...[
              const SizedBox(height: 6),
              Text(_urlError!, style: TextStyle(fontSize: 11, color: cs.error)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final id in List.of(_retainedIds)) _existingTile(id, cs),
                for (var i = 0; i < _newImages.length; i++) _newTile(i),
                if (_totalImages < _maxImages) _addTile(cs),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  /// An image already attached to the discussion (from
  /// `metadata.media_file_ids`), with its signed URL resolved through the
  /// existing media flow. Removing it only updates local state — the
  /// detach happens on save through the authorized `delete_media` path.
  Widget _existingTile(String id, ColorScheme cs) {
    final url = _existingUrls[id];
    Widget image;
    if (url != null) {
      image = Image.network(
        url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _placeholderTile(cs, Icons.broken_image_outlined),
      );
    } else if (_loadingUrls) {
      image = _placeholderTile(cs, null, spinner: true);
    } else {
      image = _placeholderTile(cs, Icons.broken_image_outlined);
    }
    return Stack(
      key: ValueKey('agri_existing_$id'),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        _removeButton(() => setState(() => _retainedIds.remove(id))),
      ],
    );
  }

  /// Preview of an image selected in this session (not yet uploaded).
  Widget _newTile(int index) {
    return Stack(
      key: ValueKey('agri_new_$index'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _newImages[index],
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        _removeButton(() => setState(() => _newImages.removeAt(index))),
      ],
    );
  }

  Widget _removeButton(VoidCallback onTap) {
    return Positioned(
      top: 4,
      right: 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  Widget _placeholderTile(
    ColorScheme cs,
    IconData? icon, {
    bool spinner = false,
  }) {
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: spinner
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.image_outlined, size: 22, color: cs.outline),
    );
  }

  Widget _addTile(ColorScheme cs) {
    return InkWell(
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
            : Icon(Icons.add_a_photo_outlined, color: cs.primary, size: 22),
      ),
    );
  }
}
