class RuntimePipelineContext<TState, TPatch, TDiff> {
  RuntimePipelineContext({
    required this.currentState,
    List<dynamic>? events,
  }) : _events = List.unmodifiable(events ?? const []);

  /// ============================================================
  /// INPUT STATE (IMMUTABLE)
  /// ============================================================
  final TState currentState;

  /// ============================================================
  /// IMMUTABLE EVENT SNAPSHOT
  /// ============================================================
  final List<dynamic> _events;

  List<dynamic>? _cachedEventsView;

  List<dynamic> get events =>
      _cachedEventsView ??= List.unmodifiable(_events);

  /// ============================================================
  /// STAGE OUTPUTS
  /// ============================================================
  TState? _nextState;
  TDiff? _diff;
  TPatch? _patch;

  bool _nextStateSet = false;
  bool _diffSet = false;
  bool _patchSet = false;

  /// ============================================================
  /// OBSERVABILITY
  /// ============================================================
  final Map<String, dynamic> metadata = {};

  /// ============================================================
  /// LIFECYCLE
  /// ============================================================
  bool _isFinalized = false;

  void finalize() {
    if (_isFinalized) {
      throw StateError(
        'PipelineContext already finalized',
      );
    }

    _isFinalized = true;
  }

  void _ensureMutable() {
    if (_isFinalized) {
      throw StateError(
        'PipelineContext is finalized and read-only',
      );
    }
  }

  /// ============================================================
  /// GETTERS
  /// ============================================================
  TState? get nextState => _nextState;

  TDiff? get diff => _diff;

  TPatch? get patch => _patch;

  bool get isFinalized => _isFinalized;

  /// ============================================================
  /// CONTROLLED SETTERS
  /// ============================================================
  void setNextState(TState value) {
    _ensureMutable();

    if (_nextStateSet) {
      throw StateError(
        'nextState already set in this pipeline run',
      );
    }

    _nextState = value;
    _nextStateSet = true;
  }

  void setDiff(TDiff value) {
    _ensureMutable();

    if (_diffSet) {
      throw StateError(
        'diff already set in this pipeline run',
      );
    }

    _diff = value;
    _diffSet = true;
  }

  void setPatch(TPatch value) {
    _ensureMutable();

    if (_patchSet) {
      throw StateError(
        'patch already set in this pipeline run',
      );
    }

    _patch = value;
    _patchSet = true;
  }

  /// ============================================================
  /// INSPECTION
  /// ============================================================
  bool get hasNextState => _nextState != null;

  bool get hasDiff => _diff != null;

  bool get hasPatch => _patch != null;

  /// ============================================================
  /// DEBUGGING
  /// ============================================================
  bool get wasMutated =>
      _nextStateSet || _diffSet || _patchSet;
}