import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFunctions? functions,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;

  Future<bool> requestAndRegister() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }
    final token = await _messaging.getToken(
      vapidKey: kIsWeb && AppConfig.fcmWebVapidKey.isNotEmpty
          ? AppConfig.fcmWebVapidKey
          : null,
    );
    if (token == null) return false;
    await _functions.httpsCallable('registerDeviceToken').call<void>({
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
    return true;
  }

  Future<void> listenForTokenRefresh() async {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _functions.httpsCallable('registerDeviceToken').call<void>({
          'token': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        });
      } catch (error, stack) {
        debugPrint('Impossibile aggiornare il token FCM: $error\n$stack');
      }
    });
  }
}
