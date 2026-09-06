import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/app_config.dart';

class NotificationService {
  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static void initialize() {
    if (!_supported ||
        _initialized ||
        AppConfig.oneSignalAppId.trim().isEmpty) {
      return;
    }
    try {
      OneSignal.initialize(AppConfig.oneSignalAppId.trim());
      _initialized = true;
    } catch (error) {
      debugPrint('OneSignal initialization skipped: $error');
    }
  }

  Future<void> identify(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
    } catch (error) {
      debugPrint('OneSignal identity not updated: $error');
    }
  }

  Future<void> clearIdentity() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
    } catch (error) {
      debugPrint('OneSignal identity cleanup failed: $error');
    }
  }

  Future<bool> requestAndRegister({String? userId}) async {
    if (!_initialized) return false;
    if (userId != null && userId.isNotEmpty) await OneSignal.login(userId);
    return OneSignal.Notifications.requestPermission(false);
  }
}
