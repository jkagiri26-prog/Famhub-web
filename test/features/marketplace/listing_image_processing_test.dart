import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/marketplace/infrastructure/services/listing_image_processing.dart';

Uint8List _webpBytes([int length = 64]) {
  final bytes = Uint8List(length);
  bytes[0] = 0x52; // R
  bytes[1] = 0x49; // I
  bytes[2] = 0x46; // F
  bytes[3] = 0x46; // F
  bytes[8] = 0x57; // W
  bytes[9] = 0x45; // E
  bytes[10] = 0x42; // B
  bytes[11] = 0x50; // P
  return bytes;
}

Uint8List _pngBytes() {
  final bytes = Uint8List(64);
  bytes[0] = 0x89;
  bytes[1] = 0x50; // P
  bytes[2] = 0x4E; // N
  bytes[3] = 0x47; // G
  return bytes;
}

void main() {
  const service = ListingImageProcessingService();

  group('isWebPBytes', () {
    test('detects the WebP container signature', () {
      expect(ListingImageProcessingService.isWebPBytes(_webpBytes()), isTrue);
    });

    test('rejects non-WebP signatures and tiny buffers', () {
      expect(ListingImageProcessingService.isWebPBytes(_pngBytes()), isFalse);
      expect(ListingImageProcessingService.isWebPBytes(Uint8List(0)), isFalse);
      expect(
        ListingImageProcessingService.isWebPBytes(
          Uint8List.fromList([1, 2, 3]),
        ),
        isFalse,
      );
    });
  });

  group('prepare', () {
    test('accepts a small already-WebP image when encoding is unavailable', () async {
      final prepared = await service.prepare(bytes: _webpBytes());

      expect(prepared.bytes, orderedEquals(_webpBytes()));
      expect(prepared.fileName, endsWith('.webp'));
    });

    test('rejects a non-WebP image', () async {
      await expectLater(
        service.prepare(bytes: _pngBytes()),
        throwsA(isA<ListingImageUnsupportedException>()),
      );
    });

    test('rejects an image above the 2 MB limit', () async {
      final oversized = _webpBytes(2 * 1024 * 1024 + 13);

      await expectLater(
        service.prepare(bytes: oversized),
        throwsA(isA<ListingImageOversizedException>()),
      );
    });

    test('rejects an empty buffer', () async {
      await expectLater(
        service.prepare(bytes: Uint8List(0)),
        throwsA(isA<ListingImageException>()),
      );
    });
  });
}
