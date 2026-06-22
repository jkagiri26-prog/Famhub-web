import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/context_controller.dart';
import '../domain/models/entity_context.dart';
import '../services/context_storage_service.dart';
import '../services/context_sync_service.dart';

final contextProvider =
    NotifierProvider<ContextController, EntityContext>(
  ContextController.new,
);
