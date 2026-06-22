import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_context.dart';
import 'context_provider.dart';

final uiContextProvider = Provider<AppContext>((ref) {
  final entity = ref.watch(contextProvider);

  return AppContext.fromEntity(entity);
});