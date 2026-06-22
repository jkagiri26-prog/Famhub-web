// ignore: dangling_library_doc_comments
/// ============================================================
/// EVENT OBSERVER PROVIDER
/// ============================================================
///
/// ✅ PURPOSE:
///   Provides the existing EventObserver as a Riverpod provider
///   so that it can be consumed by the UI and runtime widgets.
///
/// ✅ PATTERN:
///   Singleton EventObserver → Provider wrapper
///
/// ✅ CONSUMES:
///   - eventBusProvider (existing)
///
/// ❌ Does NOT:
///   - Duplicate EventObserver functionality
///   - Manage observer lifecycle beyond app scope
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/events/event_bus_provider.dart';
import 'package:famhub_app/core/observability/event_observer.dart';

final eventObserverProvider = Provider<EventObserver>((ref) {
  final bus = ref.read(eventBusProvider);
  final observer = EventObserver(bus);
  observer.start();

  ref.onDispose(() {
    observer.stop();
  });

  return observer;
});
