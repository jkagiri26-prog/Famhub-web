import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_edit_images_state.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_image_file.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/features/marketplace/infrastructure/services/listing_image_processing.dart';

/// ============================================================
/// LISTING EDIT — PHOTOS SECTION (STAGED EDITOR)
/// ============================================================
///
/// Lets the seller add photos to an existing listing (including one that has
/// no image yet) and stage removal of existing ones.
///
/// Every change is STAGED in [ListingEditImagesState] and reported up through
/// [onStateChanged]; nothing is persisted here. The Listing Edit Save flow
/// commits the staged draft through the hardened media contract only:
///   - stage add      → prepared `SelectedListingImage` (upload_media on Save)
///   - stage removal  → `media.files.id` (delete_media on Save)
///
/// The client never writes `marketplace.listings.images`, never generates
/// public Storage URLs and never sends ownership claims.
///
/// Existing photos are displayed via `media_get_by_context` (signed URLs);
/// the staged draft is compared using `media.files.id` identity only.
/// ============================================================
class ListingEditImagesSection extends ConsumerStatefulWidget {
  final String listingId;

  /// Called whenever the staged image draft changes (additions / removals).
  /// A picker that opens and closes without staging anything never fires.
  final ValueChanged<ListingEditImagesState> onStateChanged;

  const ListingEditImagesSection({
    super.key,
    required this.listingId,
    required this.onStateChanged,
  });

  @override
  ConsumerState<ListingEditImagesSection> createState() =>
      _ListingEditImagesSectionState();
}

class _ListingEditImagesSectionState
    extends ConsumerState<ListingEditImagesSection> {
  static const int _maxPhotos =
      ListingImageProcessingService.maxImagesPerListing;

  final ImagePicker _picker = ImagePicker();
  final ListingImageProcessingService _processor =
      const ListingImageProcessingService();

  bool _busy = false;

  /// Photos staged for addition this session (not yet uploaded). Bytes power
  /// the immediate preview; upload happens only when Save commits the draft.
  final List<SelectedListingImage> _stagedAdditions = [];

  /// `media.files.id` values of existing photos staged for removal. These are
  /// hidden from the active grid and can be restored before Save.
  final Set<String> _stagedRemovedIds = {};

  void _emit() {
    widget.onStateChanged(
      ListingEditImagesState(
        addedImages: List<SelectedListingImage>.from(_stagedAdditions),
        removedIds: Set<String>.from(_stagedRemovedIds),
      ),
    );
  }

  Future<void> _stageAddPhotos() async {
    if (_busy) return;
    final remaining = _maxPhotos -
        _stagedAdditions.length -
        _existingNotStagedRemovedCount();
    if (remaining <= 0) return;

    setState(() => _busy = true);

    List<XFile> picked = const [];
    try {
      if (remaining == 1) {
        final single = await _picker.pickImage(source: ImageSource.gallery);
        picked = single == null ? const [] : [single];
      } else {
        picked = await _picker.pickMultiImage(limit: remaining);
      }
    } on PlatformException {
      _showMessage(
        'Photo access is not allowed. Enable it in your device settings.',
        isError: true,
      );
      if (mounted) setState(() => _busy = false);
      return;
    } catch (_) {
      _showMessage('Could not open your photo gallery.', isError: true);
      if (mounted) setState(() => _busy = false);
      return;
    }

    if (!mounted) return;

    final failures = <String>[];
    for (final file in picked) {
      if (_stagedAdditions.length + _existingNotStagedRemovedCount() >=
          _maxPhotos) {
        break;
      }
      try {
        final bytes = await file.readAsBytes();
        final prepared = await _processor.prepare(
          bytes: bytes,
          sourceName: file.name,
        );
        setState(() => _stagedAdditions.add(prepared));
      } on ListingImageException catch (e) {
        failures.add(e.message);
      } catch (_) {
        failures.add('This photo could not be read. Choose another one.');
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    _emit();

    if (failures.isNotEmpty) {
      _showMessage(
        failures.length == 1
            ? failures.first
            : '${failures.length} photos were not added.',
        isError: true,
      );
    } else if (_stagedAdditions.isNotEmpty) {
      _showMessage('Photo added. Save to publish it.');
    }
  }

  void _unstageAdded(int index) {
    if (_busy) return;
    setState(() => _stagedAdditions.removeAt(index));
    _emit();
  }

  void _stageRemoval(ListingImageFile image) {
    if (_busy) return;
    setState(() {
      _stagedRemovedIds.add(image.id);
      // The removed photo no longer occupies a slot, so any staged additions
      // that were waiting for capacity can stay without exceeding the limit.
    });
    _emit();
  }

  void _restoreAllRemovals() {
    if (_busy) return;
    final photosAsync = ref.read(listingMediaFilesProvider(widget.listingId));
    final existingCount = photosAsync.value?.length ?? 0;
    final restoredTotal =
        existingCount + _stagedAdditions.length - _stagedRemovedIds.length;
    if (restoredTotal > _maxPhotos) {
      _showMessage(
        'Cannot restore the photo: the $_maxPhotos-photo limit would be '
        'exceeded. Remove one of the added photos first.',
        isError: true,
      );
      return;
    }
    setState(() => _stagedRemovedIds.clear());
    _emit();
  }

  int _existingNotStagedRemovedCount() {
    final photosAsync = ref.read(listingMediaFilesProvider(widget.listingId));
    final photos = photosAsync.value ?? const <ListingImageFile>[];
    return photos.where((p) => !_stagedRemovedIds.contains(p.id)).length;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  String _shortError(Object? error) {
    final text = error.toString().trim();
    if (text.length <= 200) return text;
    return '${text.substring(0, 200)}…';
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(listingMediaFilesProvider(widget.listingId));
    final photos = photosAsync.value ?? const <ListingImageFile>[];
    final countKnown = photosAsync.hasValue;

    final existingVisible =
        photos.where((p) => !_stagedRemovedIds.contains(p.id)).toList();
    final effectiveCount = existingVisible.length + _stagedAdditions.length;
    final rawRemaining = countKnown
        ? _maxPhotos - effectiveCount
        : _maxPhotos - _stagedAdditions.length;
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    final hasRemovals = _stagedRemovedIds.isNotEmpty;

    return _SectionShell(
      child: Column(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countKnown
                      ? '${existingVisible.length + _stagedAdditions.length}/$_maxPhotos'
                      : '…/$_maxPhotos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (photosAsync.hasError) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    // ignore: lines_longer_than_80_chars
                    'Could not load existing photos. '
                    '${_shortError(photosAsync.error)}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => ref.invalidate(
                    listingMediaFilesProvider(widget.listingId),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ] else if (photosAsync.isLoading) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.photo_outlined,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  'Loading photos...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ] else if (photos.isEmpty && _stagedAdditions.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'No photos yet. Add up to $_maxPhotos photos to show your '
              'product.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final image in existingVisible)
                _ExistingPhotoTile(
                  image: image,
                  busy: _busy,
                  onRemove: () => _stageRemoval(image),
                ),
              for (var i = 0; i < _stagedAdditions.length; i++)
                _StagedAdditionTile(
                  bytes: _stagedAdditions[i].bytes,
                  busy: _busy,
                  onRemove: () => _unstageAdded(i),
                ),
              if (remaining > 0)
                _AddTile(
                  busy: _busy,
                  remaining: remaining,
                  onTap: _busy ? null : _stageAddPhotos,
                ),
            ],
          ),
          if (hasRemovals) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline,
                      size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_stagedRemovedIds.length} photo'
                      '${_stagedRemovedIds.length == 1 ? '' : 's'} will be '
                      'removed when you save.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: Colors.red.shade700,
                    ),
                    onPressed: _busy ? null : _restoreAllRemovals,
                    child: const Text('Undo'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared card shell for the photos section.
class _SectionShell extends StatelessWidget {
  final Widget child;

  const _SectionShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

/// Renders one existing (remote) photo with a stage-removal action.
class _ExistingPhotoTile extends StatelessWidget {
  final ListingImageFile image;
  final bool busy;
  final VoidCallback onRemove;

  const _ExistingPhotoTile({
    required this.image,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              image.url,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xfff1f5f2),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: busy ? null : onRemove,
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

/// Local preview of a photo staged for addition, rendered from its bytes.
class _StagedAdditionTile extends StatelessWidget {
  final Uint8List bytes;
  final bool busy;
  final VoidCallback onRemove;

  const _StagedAdditionTile({
    required this.bytes,
    required this.busy,
    required this.onRemove,
  });

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
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xfff1f5f2),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: busy ? null : onRemove,
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

/// Add-photo tile (hidden once the listing is at the photo limit).
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
                    remaining > 1 ? 'Add $remaining photos' : 'Add a photo',
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
