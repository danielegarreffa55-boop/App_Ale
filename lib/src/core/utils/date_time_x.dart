import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';

extension SalonDateTime on DateTime {
  tz.TZDateTime get inStudioTimezone => tz.TZDateTime.from(
    isUtc ? this : toUtc(),
    tz.getLocation(AppConfig.timezone),
  );

  String get italianDate =>
      DateFormat('EEEE d MMMM yyyy', 'it_IT').format(inStudioTimezone);

  String get italianTime =>
      DateFormat('HH:mm', 'it_IT').format(inStudioTimezone);

  String get italianDateTime => '$italianDate, ore $italianTime';
}
