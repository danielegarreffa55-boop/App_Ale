import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/bootstrap/backend_readiness.dart';
import 'core/bootstrap/backend_wait_gate.dart';
import 'core/bootstrap/startup_sequence.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'routing/app_router.dart';

class SalonApp extends StatefulWidget {
  const SalonApp({
    required this.backendReady,
    this.initialReadiness,
    this.readinessRetry,
    this.authRepository,
    super.key,
  });

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[Locale('it', 'IT'), Locale('en')];

  final bool backendReady;
  final Future<bool>? initialReadiness;
  final ReadinessAttempt? readinessRetry;
  final AuthRepository? authRepository;

  @override
  State<SalonApp> createState() => _SalonAppState();
}

class _SalonAppState extends State<SalonApp> {
  late final AuthRepository _authRepository;
  late final StartupRouteState _startupState;
  late final StartupSequence _startupSequence;
  late final Future<bool>? _initialStartup;
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? AuthRepository.instance;
    _startupSequence = StartupSequence(_restoreSession);
    _startupState = StartupRouteState(complete: !widget.backendReady);
    router = createAppRouter(
      widget.backendReady,
      _authRepository,
      startupState: _startupState,
    );
    _initialStartup = widget.backendReady
        ? _startupSequence.run(widget.initialReadiness ?? Future.value(false))
        : null;
  }

  Future<void> _restoreSession() async {
    NotificationService.initialize();
    await _authRepository.initialize();
  }

  Future<bool> _retryStartup() => _startupSequence.run(
    (widget.readinessRetry ?? () => BackendReadiness().check()).call(),
  );

  void _openApp() {
    _startupState.finish();
  }

  @override
  void dispose() {
    router.dispose();
    _startupState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.editorial,
      locale: const Locale('it', 'IT'),
      localizationsDelegates: SalonApp.localizationsDelegates,
      supportedLocales: SalonApp.supportedLocales,
      routerConfig: router,
      builder: (context, child) => BackendWaitGate(
        initialAttempt: _initialStartup,
        retry: _retryStartup,
        onReady: _openApp,
        onAttemptTimeout: _startupSequence.expireCurrentAttempt,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
