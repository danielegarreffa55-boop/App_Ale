import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('Europe/Rome applica ora legale e solare', () {
    final rome = tz.getLocation('Europe/Rome');
    final winter = tz.TZDateTime(rome, 2026, 1, 15, 12);
    final summer = tz.TZDateTime(rome, 2026, 7, 15, 12);
    expect(winter.timeZoneOffset, const Duration(hours: 1));
    expect(summer.timeZoneOffset, const Duration(hours: 2));
  });
}
