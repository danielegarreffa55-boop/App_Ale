import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/appointments/domain/availability_engine.dart';

void main() {
  test('durata e buffer devono rientrare nell\u2019orario di chiusura', () {
    final day = DateTime.utc(2026, 9, 1);
    final slots = calculateAvailability(
      opensAt: day.add(const Duration(hours: 8)),
      closesAt: day.add(const Duration(hours: 9)),
      durationMinutes: 30,
      bufferMinutes: 10,
      intervalMinutes: 15,
    );
    expect(slots.map((slot) => slot.start.minute), [0, 15]);
  });

  test('gli intervalli che toccano il bordo non si sovrappongono', () {
    final first = TimeRange(
      DateTime.utc(2026, 9, 1, 8),
      DateTime.utc(2026, 9, 1, 8, 30),
    );
    final second = TimeRange(
      DateTime.utc(2026, 9, 1, 8, 30),
      DateTime.utc(2026, 9, 1, 9),
    );
    expect(first.overlaps(second), isFalse);
  });

  test('i lock coprono l\u2019intero intervallo a bucket da cinque minuti', () {
    final keys = lockBucketKeys(
      startAt: DateTime.utc(2026, 9, 1, 8, 2),
      endAt: DateTime.utc(2026, 9, 1, 8, 12),
    );
    expect(keys, hasLength(3));
  });
}
