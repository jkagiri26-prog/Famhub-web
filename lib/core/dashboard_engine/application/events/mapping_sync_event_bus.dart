import 'dart:async';

class MappingSyncEventBus {
  MappingSyncEventBus._();

  static final MappingSyncEventBus instance =
      MappingSyncEventBus._();

  final StreamController<void> _controller =
      StreamController.broadcast();

  Stream<void> get stream => _controller.stream;

  void emit() {
    _controller.add(null);
  }
}