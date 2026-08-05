class TestingWindow {
  const TestingWindow({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  String get formatted {
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start – $end';
  }

  static TestingWindow? tryParse(Map<String, dynamic> data) {
    final start = _read(data, const [
      'testingWindowStart',
      'testing_window_start',
      'startTime',
      'preferredStartTime',
      'windowStart',
    ]);
    final end = _read(data, const [
      'testingWindowEnd',
      'testing_window_end',
      'endTime',
      'preferredEndTime',
      'windowEnd',
    ]);

    // Nested map shape: testingWindow: { start, end } / { startTime, endTime }
    if (start.isEmpty && end.isEmpty) {
      final nested = data['testingWindow'];
      if (nested is Map) {
        final map = Map<String, dynamic>.from(nested);
        final nestedStart = _read(map, const ['start', 'startTime', 'from']);
        final nestedEnd = _read(map, const ['end', 'endTime', 'to']);
        if (nestedStart.isEmpty && nestedEnd.isEmpty) return null;
        return TestingWindow(start: nestedStart, end: nestedEnd);
      }
      return null;
    }

    return TestingWindow(start: start, end: end);
  }

  static String _read(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
