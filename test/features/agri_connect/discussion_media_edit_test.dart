/// ============================================================
/// AGRI CONNECT — DISCUSSION MEDIA EDIT TESTS
/// ============================================================
///
/// Covers the pure edit-planning and reconciliation logic behind the
/// Edit Discussion dialog:
///   - retaining existing images unchanged
///   - removing one image
///   - adding one image (upload + persist)
///   - replacing an image (remove + add)
///   - enforcing the two-image limit
///   - upload/persist failure (rollback, partial-failure signalling)
///   - detach failure after persist
///   - fetch failure never empties the media list (plan is metadata-based)
/// ============================================================
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/features/agri_connect/application/providers/discussion_provider.dart';

Uint8List _bytes(int n) => Uint8List.fromList(List.filled(n, 1));

/// Recording fakes for the reconcile callbacks.
class _Recorder {
  final List<String> uploads = [];
  final List<List<String>> persists = [];
  final List<String> detaches = [];
  final List<String> order = [];
  int uploadCalls = 0;
  bool failUploadAt = false;
  bool failPersist = false;
  bool failDetach = false;

  Future<String> upload(Uint8List bytes) async {
    order.add('upload');
    uploadCalls++;
    if (failUploadAt && uploadCalls > 1) {
      throw Exception('upload broke');
    }
    final id = 'new$uploadCalls';
    uploads.add(id);
    return id;
  }

  Future<void> persist(List<String> ids) async {
    order.add('persist');
    if (failPersist) throw Exception('persist broke');
    persists.add(List.of(ids));
  }

  Future<void> detach(String fileId) async {
    order.add('detach:$fileId');
    if (failDetach && !fileId.startsWith('new')) {
      throw Exception('detach broke');
    }
    detaches.add(fileId);
  }
}

void main() {
  group('planDiscussionMediaEdit', () {
    test('retaining existing images is a no-op (nothing to reconcile)', () {
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a', 'b'},
        newImageCount: 0,
      );
      expect(plan.retainedIds, ['a', 'b']);
      expect(plan.removedIds, isEmpty);
      expect(plan.touchesMedia, isFalse);
    });

    test('removing one image schedules exactly that id for detach', () {
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a'},
        newImageCount: 0,
      );
      expect(plan.retainedIds, ['a']);
      expect(plan.removedIds, ['b']);
      expect(plan.touchesMedia, isTrue);
      expect(plan.total, 1);
    });

    test('adding one image to a single existing image stays within limit', () {
      final plan = planDiscussionMediaEdit(
        originalIds: ['a'],
        retainedIds: {'a'},
        newImageCount: 1,
      );
      expect(plan.total, 2);
      expect(plan.touchesMedia, isTrue);
      expect(plan.removedIds, isEmpty);
    });

    test('replacing an image = keep one, remove one, add one', () {
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a'},
        newImageCount: 1,
      );
      expect(plan.retainedIds, ['a']);
      expect(plan.removedIds, ['b']);
      expect(plan.total, 2);
    });

    test('two-image limit: two retained plus a new image throws', () {
      expect(
        () => planDiscussionMediaEdit(
          originalIds: ['a', 'b'],
          retainedIds: {'a', 'b'},
          newImageCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test('two-image limit: two new images on an empty discussion is fine', () {
      final plan = planDiscussionMediaEdit(
        originalIds: const [],
        retainedIds: const {},
        newImageCount: 2,
      );
      expect(plan.total, 2);
    });

    test('ids outside the original list are ignored', () {
      final plan = planDiscussionMediaEdit(
        originalIds: ['a'],
        retainedIds: {'a', 'bogus'},
        newImageCount: 0,
      );
      expect(plan.retainedIds, ['a']);
      expect(plan.removedIds, isEmpty);
    });

    test('a failed fetch cannot empty the list: metadata seeds the plan', () {
      // Simulates: URL loading failed, so the dialog kept every id from
      // metadata.media_file_ids and the author saved without changes.
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a', 'b'},
        newImageCount: 0,
      );
      expect(plan.retainedIds, ['a', 'b']);
      expect(plan.touchesMedia, isFalse);
    });
  });

  group('reconcileDiscussionMedia', () {
    test('no-op plan performs no media calls', () async {
      final r = _Recorder();
      final plan = planDiscussionMediaEdit(
        originalIds: ['a'],
        retainedIds: {'a'},
        newImageCount: 0,
      );
      await reconcileDiscussionMedia(
        plan: plan,
        newImages: const [],
        upload: r.upload,
        persist: r.persist,
        detach: r.detach,
      );
      expect(r.order, isEmpty);
    });

    test('adding one image uploads, then persists retained + new', () async {
      final r = _Recorder();
      final plan = planDiscussionMediaEdit(
        originalIds: ['a'],
        retainedIds: {'a'},
        newImageCount: 1,
      );
      await reconcileDiscussionMedia(
        plan: plan,
        newImages: [_bytes(8)],
        upload: r.upload,
        persist: r.persist,
        detach: r.detach,
      );
      expect(r.uploads, ['new1']);
      expect(r.persists, [
        ['a', 'new1'],
      ]);
      expect(r.detaches, isEmpty);
    });

    test('removing one image persists before detaching (safe order)', () async {
      final r = _Recorder();
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a'},
        newImageCount: 0,
      );
      await reconcileDiscussionMedia(
        plan: plan,
        newImages: const [],
        upload: r.upload,
        persist: r.persist,
        detach: r.detach,
      );
      expect(r.persists, [
        ['a'],
      ]);
      expect(r.detaches, ['b']);
      expect(r.order.indexOf('persist'), lessThan(r.order.indexOf('detach:b')));
    });

    test(
      'replacing an image detaches the old id and keeps the new one',
      () async {
        final r = _Recorder();
        final plan = planDiscussionMediaEdit(
          originalIds: ['old'],
          retainedIds: const {},
          newImageCount: 1,
        );
        await reconcileDiscussionMedia(
          plan: plan,
          newImages: [_bytes(8)],
          upload: r.upload,
          persist: r.persist,
          detach: r.detach,
        );
        expect(r.persists, [
          ['new1'],
        ]);
        expect(r.detaches, ['old']);
      },
    );

    test(
      'second upload fails → first upload rolled back, nothing persisted',
      () async {
        final r = _Recorder()..failUploadAt = true;
        final plan = planDiscussionMediaEdit(
          originalIds: const [],
          retainedIds: const {},
          newImageCount: 2,
        );
        await expectLater(
          reconcileDiscussionMedia(
            plan: plan,
            newImages: [_bytes(8), _bytes(8)],
            upload: r.upload,
            persist: r.persist,
            detach: r.detach,
          ),
          throwsA(
            isA<DiscussionMediaPhaseException>()
                .having((e) => e.listPersisted, 'listPersisted', isFalse)
                .having((e) => e.stage, 'stage', DiscussionMediaStage.upload),
          ),
        );
        expect(r.detaches, ['new1'], reason: 'uploaded so far must roll back');
        expect(r.persists, isEmpty);
      },
    );

    test(
      'persist fails → new uploads rolled back, listPersisted false',
      () async {
        final r = _Recorder()..failPersist = true;
        final plan = planDiscussionMediaEdit(
          originalIds: ['a'],
          retainedIds: {'a'},
          newImageCount: 1,
        );
        await expectLater(
          reconcileDiscussionMedia(
            plan: plan,
            newImages: [_bytes(8)],
            upload: r.upload,
            persist: r.persist,
            detach: r.detach,
          ),
          throwsA(
            isA<DiscussionMediaPhaseException>()
                .having((e) => e.listPersisted, 'listPersisted', isFalse)
                .having((e) => e.stage, 'stage', DiscussionMediaStage.persist),
          ),
        );
        expect(r.detaches, ['new1']);
        expect(r.persists, isEmpty);
      },
    );

    test('detach of a removed image fails → listPersisted true', () async {
      final r = _Recorder()..failDetach = true;
      final plan = planDiscussionMediaEdit(
        originalIds: ['a', 'b'],
        retainedIds: {'a'},
        newImageCount: 0,
      );
      await expectLater(
        reconcileDiscussionMedia(
          plan: plan,
          newImages: const [],
          upload: r.upload,
          persist: r.persist,
          detach: r.detach,
        ),
        throwsA(
          isA<DiscussionMediaPhaseException>()
              .having((e) => e.listPersisted, 'listPersisted', isTrue)
              .having((e) => e.stage, 'stage', DiscussionMediaStage.detach),
        ),
      );
      expect(r.persists, [
        ['a'],
      ], reason: 'list already persisted when cleanup failed');
    });
  });

  group('DiscussionEditException', () {
    test('messages distinguish text-only save from cleanup failure', () {
      const textOnly = DiscussionEditException(
        textSaved: true,
        mediaSaved: false,
        cause: 'boom',
      );
      const cleanup = DiscussionEditException(
        textSaved: true,
        mediaSaved: true,
        cause: 'boom',
      );
      expect(textOnly.userMessage, contains('image changes were not'));
      expect(cleanup.userMessage, contains('could not be removed'));
    });

    test('stage-tagged failures name the exact media sub-step', () {
      const uploadFailure = DiscussionEditException(
        textSaved: true,
        mediaSaved: false,
        stage: DiscussionMediaStage.upload,
        cause: 'Upload failed: unsupported context',
      );
      const persistFailure = DiscussionEditException(
        textSaved: true,
        mediaSaved: false,
        stage: DiscussionMediaStage.persist,
        cause: 'metadata write rejected',
      );
      expect(
        uploadFailure.userMessage,
        allOf(contains('uploading a new image'), contains('Upload failed')),
      );
      expect(persistFailure.userMessage, contains('saving the image list'));
      expect(uploadFailure.toString(), contains('uploading a new image'));
    });

    test('stage labels identify upload, persist and detach', () {
      expect(DiscussionMediaStage.upload.label, 'uploading a new image');
      expect(DiscussionMediaStage.persist.label, 'saving the image list');
      expect(DiscussionMediaStage.detach.label, 'removing an old image');
    });
  });
}
