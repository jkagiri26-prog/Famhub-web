import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_image_file.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';
import 'package:famhub_app/features/marketplace/infrastructure/services/listing_image_processing.dart';

/// ============================================================
/// LISTING EDIT — PHOTOS SECTION
/// ============================================================
///
/// Lets the seller add photos to an existing listing (including one that has
/// no image yet) and remove existing ones.
///
/// Reuses the hardened media contract only:
///   - display existing photos  → media_get_by_context (signed URLs)
///   - add photos               → upload_media
///   - remove photos            → delete_media
///
/// The client never writes `marketplace.listings.images`, never generates
/// public Storage URLs and never sends ownership claims.
/// ============================================================
class ListingEditImagesSection extends ConsumerStatefulWidget {
  final String listingId;

  const ListingEditImagesSection({super.key, required this.listingId});

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

  Future<void> _addPhotos(int currentCount) async {
    if (_busy) return;
    final remaining = _maxPhotos - currentCount;
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

    final prepared = <SelectedListingImage>[];
    final prepFailures = <String>[];
    for (final file in picked) {
      try {
        final bytes = await file.readAsBytes();
        prepared.add(
          await _processor.prepare(bytes: bytes, sourceName: file.name),
        );
      } on ListingImageException catch (e) {
        prepFailures.add(e.message);
      } catch (_) {
        prepFailures.add('This photo could not be read. Choose another one.');
      }
    }

    var uploaded = 0;
    final uploadFailures = <String>[];
    for (final image in prepared) {
      try {
        await ref
            .read(marketplaceProvider.notifier)
            .uploadListingPhoto(
              listingId: widget.listingId,
              bytes: image.bytes,
              fileName: image.fileName,
            );
        uploaded++;
      } catch (e) {
        uploadFailures.add(_describePhotoError(e));
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    final problems = [...prepFailures, ...uploadFailures];
    if (problems.isNotEmpty) {
      _showMessage(
        problems.length == 1
            ? problems.first
            : '${problems.length} photos were not added.',
        isError: true,
      );
    } else if (uploaded > 0) {
      _showMessage(uploaded == 1 ? 'Photo added.' : '$uploaded photos added.');
    }
  }

  Future<void> _removePhoto(ListingImageFile image) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This photo will be removed from the listing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceProvider.notifier)
          .deleteListingPhoto(listingId: widget.listingId, fileId: image.id);
      if (!mounted) return;
      _showMessage('Photo removed.');
    } catch (e) {
      if (mounted) {
        _showMessage(_describePhotoError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  String _describePhotoError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('denied') ||
        lower.contains('owner')) {
      return "You don't have permission to change photos on this listing.";
    }
    if (lower.contains('sign in') ||
        lower.contains('expired') ||
        lower.contains('session')) {
      return 'Please sign in to change photos.';
    }
    if (lower.contains('too large') || lower.contains('2 mb')) {
      return 'The photo is larger than 2 MB.';
    }
    if (lower.contains('format') ||
        lower.contains('unsupported') ||
        lower.contains('webp')) {
      return 'That photo format is not supported.';
    }
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('timeout')) {
      return "Couldn't reach the server. Check your connection and try again.";
    }
    final cleaned = text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
    return cleaned.isEmpty ? 'Please try again.' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(listingMediaFilesProvider(widget.listingId));

    // Existing photos (empty while loading or on load failure). The Add tile
    // stays available so a seller can always add a photo — even to a listing
    // that has no photos yet, or when listing the existing ones fails.
    final photos = photosAsync.value ?? const <ListingImageFile>[];
    final countKnown = photosAsync.hasValue;
    final remaining = countKnown ? _maxPhotos - photos.length : _maxPhotos;

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
                  countKnown ? '${photos.length}/$_maxPhotos' : '…/$_maxPhotos',
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
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Could not load existing photos.',
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
          ] else if (photos.isEmpty) ...[
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
              for (final image in photos)
                _PhotoTile(
                  image: image,
                  busy: _busy,
                  onRemove: () => _removePhoto(image),
                ),
              if (photos.length < _maxPhotos)
                _AddTile(
                  busy: _busy,
                  remaining: remaining,
                  onTap: _busy ? null : () => _addPhotos(photos.length),
                ),
            ],
          ),
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

/// Renders one existing photo with a remove action.
class _PhotoTile extends StatelessWidget {
  final ListingImageFile image;
  final bool busy;
  final VoidCallback onRemove;

  const _PhotoTile({
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
