import 'dart:async';

abstract class AppEvent {
  final DateTime timestamp;
  AppEvent() : timestamp = DateTime.now();
}

class AppEventBus {
  AppEventBus._internal();
  static final AppEventBus instance = AppEventBus._internal();

  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  bool _isDisposed = false;

  Stream<AppEvent> get stream => _controller.stream;

  void emit(AppEvent event) {
    if (_isDisposed || _controller.isClosed) return;
    _controller.add(event);
  }

  StreamSubscription<AppEvent> listen(
    void Function(AppEvent event) onEvent,
  ) {
    return stream.listen(onEvent);
  }

  Stream<T> on<T extends AppEvent>() {
    return stream.where((e) => e is T).cast<T>();
  }

  StreamSubscription<T> subscribe<T extends AppEvent>(
    void Function(T event) onEvent,
  ) {
    return on<T>().listen(onEvent);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.close();
  }
}