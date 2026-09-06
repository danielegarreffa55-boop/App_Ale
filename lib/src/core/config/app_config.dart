abstract final class AppConfig {
  static const studioName = String.fromEnvironment(
    'STUDIO_NAME',
    defaultValue: 'Alessio Garreffa Hair',
  );
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Alessio Garreffa Hair',
  );
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
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
  static const backendApiUrl = String.fromEnvironment('BACKEND_API_URL');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static const apiPollSeconds = int.fromEnvironment(
    'API_POLL_SECONDS',
    defaultValue: 5,
  );

  static bool get isBackendConfigured => backendApiUrl.trim().isNotEmpty;
}
