import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../network/backend_api.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFunctions? functions,
    BackendApi? backendApi,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _backendApi = backendApi ?? BackendApi();

  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;
  final BackendApi _backendApi;

  Future<void> _register(String token) async {
    final data = <String, Object?>{
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
    if (_backendApi.enabled) {
      await _backendApi.post('/v1/devices', data);
    } else {
      await _functions.httpsCallable('registerDeviceToken').call<void>(data);
    }
  }

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
    await _register(token);
    return true;
  }

  Future<void> listenForTokenRefresh() async {
    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _register(token);
      } catch (error, stack) {
        debugPrint('Impossibile aggiornare il token FCM: $error\n$stack');
      }
    });
  }
}
