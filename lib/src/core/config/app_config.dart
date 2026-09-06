import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const studioName = String.fromEnvironment(
    'STUDIO_NAME',
    defaultValue: 'Alessio Garreffa Hair',
  );
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Alessio Garreffa Hair',
  );
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '',
  );
  static const supportPhone = String.fromEnvironment(
    'SUPPORT_PHONE',
    defaultValue: '+39 342 535 5594',
  );
  static const address = String.fromEnvironment(
    'ADDRESS',
    defaultValue: 'Via Cottolengo 44, 10048 Vinovo TO',
  );
  static const timezone = String.fromEnvironment(
    'TIMEZONE',
    defaultValue: 'Europe/Rome',
  );
  static const currency = String.fromEnvironment(
    'CURRENCY',
    defaultValue: 'EUR',
  );
  static const reminderTime = String.fromEnvironment(
    'REMINDER_TIME',
    defaultValue: '18:00',
  );

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const recaptchaV3SiteKey = String.fromEnvironment(
    'RECAPTCHA_V3_SITE_KEY',
  );
  static const fcmWebVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
  static const useFirebaseEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const firebaseEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const _webAppId = String.fromEnvironment('FIREBASE_APP_ID_WEB');

  static String get firebaseAppId {
    if (kIsWeb) return _webAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _iosAppId,
      _ => _androidAppId,
    };
  }

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseAppId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
    measurementId: firebaseMeasurementId.isEmpty ? null : firebaseMeasurementId,
    iosBundleId: 'it.studio.salon.salonBooking',
  );
}
