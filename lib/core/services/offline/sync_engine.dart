import 'offline_queue_service.dart';
import 'queue_models.dart';

class SyncEngine {
  final OfflineQueueService queueService;

  SyncEngine(this.queueService);

  Future<void> sync() async {
    final queue = await queueService.getQueue();

    for (final item in queue) {
      try {
        await _process(item);
      } catch (e) {
        // leave item for retry
      }
    }

    await queueService.clear();
  }

  Future<void> _process(QueueItem item) async {
    switch (item.action) {
      case 'create_listing':
        await _createListing(item.payload);
        break;

      case 'update_stock':
        await _updateStock(item.payload);
        break;

      default:
        throw Exception('Unknown action');
    }
  }

  Future<void> _createListing(Map payload) async {
    // call Supabase insert
  }

  Future<void> _updateStock(Map payload) async {
    // call Supabase update
  }
}