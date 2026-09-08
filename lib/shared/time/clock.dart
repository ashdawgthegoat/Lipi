/// Interface for injectable clock to enable deterministic time testing.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class MockClock implements Clock {
  DateTime _current;

  MockClock(this._current);

  @override
  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void set(DateTime newTime) {
    _current = newTime;
  }
}
