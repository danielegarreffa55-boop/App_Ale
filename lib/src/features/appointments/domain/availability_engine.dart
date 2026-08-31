class TimeRange {
  TimeRange(this.start, this.end)
    : assert(!end.isBefore(start), 'La fine precede l\u2019inizio');

  final DateTime start;
  final DateTime end;

  bool overlaps(TimeRange other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}

List<TimeRange> calculateAvailability({
  required DateTime opensAt,
  required DateTime closesAt,
  required int durationMinutes,
  int bufferMinutes = 0,
  int intervalMinutes = 15,
  Iterable<TimeRange> unavailable = const [],
}) {
  if (durationMinutes <= 0 || intervalMinutes <= 0 || bufferMinutes < 0) {
    throw ArgumentError('Durata, buffer o intervallo non validi');
  }
  final slots = <TimeRange>[];
  var cursor = opensAt;
  final occupied = unavailable.toList(growable: false);
  while (true) {
    final serviceEnd = cursor.add(Duration(minutes: durationMinutes));
    final blockedEnd = serviceEnd.add(Duration(minutes: bufferMinutes));
    if (blockedEnd.isAfter(closesAt)) break;
    final candidate = TimeRange(cursor, blockedEnd);
    if (!occupied.any(candidate.overlaps)) {
      slots.add(TimeRange(cursor, serviceEnd));
    }
    cursor = cursor.add(Duration(minutes: intervalMinutes));
  }
  return slots;
}

List<String> lockBucketKeys({
  required DateTime startAt,
  required DateTime endAt,
  int bucketMinutes = 5,
}) {
  if (!startAt.isUtc || !endAt.isUtc) {
    throw ArgumentError('Le date dei lock devono essere UTC');
  }
  if (!endAt.isAfter(startAt) || bucketMinutes <= 0) {
    throw ArgumentError('Intervallo lock non valido');
  }
  final bucketMs = Duration(minutes: bucketMinutes).inMilliseconds;
  var cursorMs = (startAt.millisecondsSinceEpoch ~/ bucketMs) * bucketMs;
  final keys = <String>[];
  while (cursorMs < endAt.millisecondsSinceEpoch) {
    keys.add(
      DateTime.fromMillisecondsSinceEpoch(
        cursorMs,
        isUtc: true,
      ).toIso8601String(),
    );
    cursorMs += bucketMs;
  }
  return keys;
}
