/// Simple cancellation token
class CancelToken {
  bool _isCancelled = false;

  /// Whether this token has been cancelled
  bool get isCancelled => _isCancelled;

  /// Cancel this token
  void cancel() {
    _isCancelled = true;
  }
}
