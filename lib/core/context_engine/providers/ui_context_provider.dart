import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/context_provider.dart';
import '../../domain/models/app_context.dart';

final uiContextProvider = Provider<AppContext>((ref) {
  final entity = ref.watch(contextProvider);

  return AppContext.fromEntity(entity);
});