import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../network/session_store.dart';
import '../notifications/notification_service.dart';

abstract final class AppBootstrap {
  static Future<bool> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(AppConfig.timezone));
    await initializeDateFormatting('it_IT');
    await SessionStore.instance.initialize();
    NotificationService.initialize();
    return AppConfig.isBackendConfigured;
  }
}
