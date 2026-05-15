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