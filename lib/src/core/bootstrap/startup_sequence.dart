typedef SessionRestorer = Future<void> Function();

class StartupSequence {
  StartupSequence(this._restoreSession);

  final SessionRestorer _restoreSession;
  int _nextAttemptId = 0;
  int get _newAttemptId => ++_nextAttemptId;
  int _currentAttemptId = 0;
  Future<void>? _restoreInFlight;

  Future<bool> run(Future<bool> readiness) async {
    final attemptId = _newAttemptId;
    _currentAttemptId = attemptId;
    if (!await readiness || attemptId != _currentAttemptId) return false;

    final existingRestore = _restoreInFlight;
    if (existingRestore != null) {
      try {
        await existingRestore;
        return attemptId == _currentAttemptId;
      } catch (_) {
        if (attemptId != _currentAttemptId) return false;
        if (identical(_restoreInFlight, existingRestore)) {
          _restoreInFlight = null;
        }
      }
    }

    final restore = _restoreSession();
    _restoreInFlight = restore;
    try {
      await restore;
      return attemptId == _currentAttemptId;
    } catch (_) {
      return false;
    } finally {
      if (identical(_restoreInFlight, restore)) _restoreInFlight = null;
    }
  }

  void expireCurrentAttempt() {
    _currentAttemptId = _newAttemptId;
  }
}
