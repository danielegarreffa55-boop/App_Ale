import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/app_config.dart';

class NotificationService {
  NotificationService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static bool _initialized = false;
  final FlutterSecureStorage _storage;

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

  Future<bool?> permissionEnabled() async {
    if (!_initialized) return null;
    try {
      final permission = await OneSignal.Notifications.permissionNative();
      final allowed =
          permission == OSNotificationPermission.authorized ||
          permission == OSNotificationPermission.provisional ||
          permission == OSNotificationPermission.ephemeral;
      return allowed && OneSignal.User.pushSubscription.optedIn == true;
    } catch (error) {
      debugPrint('OneSignal permission status unavailable: $error');
      return null;
    }
  }

  Future<bool> requestAndRegister({String? userId}) async {
    if (!_initialized) return false;
    if (userId != null && userId.isNotEmpty) await OneSignal.login(userId);
    final allowed = await OneSignal.Notifications.requestPermission(true);
    if (allowed) OneSignal.User.pushSubscription.optIn();
    return allowed;
  }

  Future<void> disable() async {
    if (!_initialized) return;
    OneSignal.User.pushSubscription.optOut();
  }

  String _promptKey(String userId) => 'agh_notification_prompt_$userId';

  Future<bool> firstPromptWasShown(String userId) async =>
      await _storage.read(key: _promptKey(userId)) == 'true';

  Future<void> markFirstPromptShown(String userId) =>
      _storage.write(key: _promptKey(userId), value: 'true');
}
