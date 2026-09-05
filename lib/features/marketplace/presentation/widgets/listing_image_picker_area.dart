import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/listing_publication.dart';
import '../../infrastructure/services/listing_image_processing.dart';

/// Simple, premium photo picker for a Marketplace listing.
///
/// Enforces the 3-image contract, converts every selection to WebP at or below
/// the 2 MB limit, previews the prepared images and allows removal before
/// upload. Only prepared images are ever surfaced to the caller via
/// [onImagesChanged].
class ListingImagePickerArea extends StatefulWidget {
  final ValueChanged<List<SelectedListingImage>> onImagesChanged;

  const ListingImagePickerArea({
    super.key,
    required this.onImagesChanged,
  });

  @override
  State<ListingImagePickerArea> createState() => _ListingImagePickerAreaState();
}

class _ListingImagePickerAreaState extends State<ListingImagePickerArea> {
  static const int _maxImages = 3;

  final ImagePicker _picker = ImagePicker();
  final ListingImageProcessingService _processor =
      const ListingImageProcessingService();

  final List<SelectedListingImage> _selected = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _selected.clear();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_busy) return;
    final remaining = _maxImages - _selected.length;
    if (remaining <= 0) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    List<XFile> picked = const [];
    try {
      if (remaining == 1) {
        final single = await _picker.pickImage(source: ImageSource.gallery);
        picked = single == null ? const [] : [single];
      } else {
        picked = await _picker.pickMultiImage(limit: remaining);
      }
    } on PlatformException catch (e) {
      _showError(
        e.code == 'camera_access_denied' ||
                e.code == 'photo_access_denied'
            ? 'Photo access is not allowed. Enable it in your device settings.'
            : 'Could not open your photo gallery.',
      );
      return;
    } catch (_) {
      _showError('Could not open your photo gallery.');
      return;
    }

    if (!mounted) return;

    final added = <SelectedListingImage>[];
    final failures = <String>[];
    for (final file in picked.take(remaining)) {
      try {
        final bytes = await file.readAsBytes();
        final prepared = await _processor.prepare(
          bytes: bytes,
          sourceName: file.name,
        );
        added.add(prepared);
      } on ListingImageException catch (e) {
        failures.add(e.message);
      } catch (_) {
        failures.add('This photo could not be read. Choose a different one.');
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (added.isNotEmpty) {
        _selected.addAll(added);
        widget.onImagesChanged(List<SelectedListingImage>.from(_selected));
      }
      if (failures.isNotEmpty) {
        _error = failures.length == 1
            ? failures.first
            : '${failures.length} photos were not added.';
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selected.removeAt(index);
      widget.onImagesChanged(List<SelectedListingImage>.from(_selected));
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Photos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_maxImages max',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _selected.length; i++)
              _PreviewTile(
                bytes: _selected[i].bytes,
                onRemove: () => _removeImage(i),
              ),
            if (_selected.length < _maxImages)
              _AddTile(
                busy: _busy,
                remaining: _maxImages - _selected.length,
                onTap: _busy ? null : _pickImages,
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final bool busy;
  final int remaining;
  final VoidCallback? onTap;

  const _AddTile({
    required this.busy,
    required this.remaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withValues(alpha: 0.35)),
        ),
        child: busy
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: primary,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 22, color: primary),
                  const SizedBox(height: 4),
                  Text(
                    remaining > 1
                        ? 'Add $remaining photos'
                        : 'Add a photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onRemove;

  const _PreviewTile({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              bytes,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xfff1f5f2),
                child: const Icon(Icons.image_outlined,
                    color: Colors.grey, size: 28),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
