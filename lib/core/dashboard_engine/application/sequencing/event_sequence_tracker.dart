class EventSequenceTracker {
  final Set<String> _seen = {};
  int _lastSequence = 0;

  bool isDuplicate(String eventId) {
    return !_seen.add(eventId);
  }

  int nextSequence() {
    return ++_lastSequence;
  }

  void reset() {
    _seen.clear();
    _lastSequence = 0;
  }
}