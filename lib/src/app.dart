import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'routing/app_router.dart';

class SalonApp extends StatefulWidget {
  const SalonApp({required this.backendReady, super.key});

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[Locale('it', 'IT'), Locale('en')];

  final bool backendReady;

  @override
  State<SalonApp> createState() => _SalonAppState();
}

class _SalonAppState extends State<SalonApp> {
  late final router = createAppRouter(
    widget.backendReady,
    AuthRepository.instance,
  );

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
    );
  }
}
