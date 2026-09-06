import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.content_cut_rounded, size: 52),
                      const SizedBox(height: 20),
                      Text(
                        AppConfig.appName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Il codice è pronto. Configura l’indirizzo HTTPS della API '
                        'FastAPI e l’App ID OneSignal in un file JSON locale, poi '
                        'avvia Flutter con --dart-define-from-file.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const SelectableText(
                        'flutter run -d android '
                        '--dart-define-from-file=config/emulator.json',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
