import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class SalonApp extends StatefulWidget {
  const SalonApp({required this.firebaseReady, super.key});

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[Locale('it', 'IT'), Locale('en')];

  final bool firebaseReady;

  @override
  State<SalonApp> createState() => _SalonAppState();
}

class _SalonAppState extends State<SalonApp> {
  late final router = createAppRouter(widget.firebaseReady);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('it', 'IT'),
      localizationsDelegates: SalonApp.localizationsDelegates,
      supportedLocales: SalonApp.supportedLocales,
      routerConfig: router,
    );
  }
}
