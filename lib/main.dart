import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/bootstrap/app_bootstrap.dart';
import 'src/core/bootstrap/backend_readiness.dart';
import 'src/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialReadiness = AppConfig.isBackendConfigured
      ? BackendReadiness().check()
      : null;
  final backendReady = await AppBootstrap.initialize();
  runApp(
    ProviderScope(
      child: SalonApp(
        backendReady: backendReady,
        initialReadiness: initialReadiness,
      ),
    ),
  );
}
