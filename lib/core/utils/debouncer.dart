import 'dart:async';

/// Collapses a burst of keystrokes into one call. Used by the job-title and
/// location search fields so typing does not fire a request per character.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Drops a pending call — e.g. when the field is cleared or closed.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
