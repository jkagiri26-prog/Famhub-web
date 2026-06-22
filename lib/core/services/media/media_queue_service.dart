import 'media_processor.dart';
import 'media_upload_service.dart';

class MediaQueueItem {
  final String filePath;

  MediaQueueItem(this.filePath);
}

class MediaQueueService {
  final MediaProcessor processor;
  final MediaUploadService uploader;

  MediaQueueService(this.processor, this.uploader);

  Future<void> processQueue(List<MediaQueueItem> queue) async {
    for (final item in queue) {
      final compressed = await processor.compress(item.filePath);
      await uploader.upload(compressed);
    }
  }
}
