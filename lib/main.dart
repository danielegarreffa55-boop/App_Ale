import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/bootstrap/app_bootstrap.dart';
import 'src/features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendReady = await AppBootstrap.initialize();
  await AuthRepository.instance.initialize();
  runApp(ProviderScope(child: SalonApp(backendReady: backendReady)));
}
