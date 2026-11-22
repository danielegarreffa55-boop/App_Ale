import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salon_booking/src/core/bootstrap/backend_readiness.dart';
import 'package:salon_booking/src/core/bootstrap/backend_wait_gate.dart';
import 'package:salon_booking/src/core/bootstrap/startup_sequence.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/auth/data/auth_repository.dart';
import 'package:salon_booking/src/routing/app_router.dart';

Widget _app({
  required Future<bool> initial,
  required Future<bool> Function() retry,
  Duration grace = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 1),
}) => MaterialApp(
  theme: AppTheme.editorial,
  home: BackendWaitGate(
    initialAttempt: initial,
    retry: retry,
    gracePeriod: grace,
    attemptTimeout: timeout,
    phrasePeriod: const Duration(milliseconds: 100),
    child: const Scaffold(body: Text('contenuto app')),
  ),
);

class _CountingPage extends StatefulWidget {
  const _CountingPage({required this.onInitialize});

  final VoidCallback onInitialize;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.onInitialize();
  }

  @override
  Widget build(BuildContext context) => const Text('destinazione');
}

void main() {
  test('readyz usa GET pubblico sull URL configurato', () async {
    late http.Request captured;
    final readiness = BackendReadiness(
      backendUrl: 'https://example.test/api/',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"status":"ready"}', 200);
      }),
    );

    expect(await readiness.check(), isTrue);
    expect(captured.method, 'GET');
    expect(captured.url, Uri.parse('https://example.test/api/readyz'));
    expect(captured.headers['Authorization'], isNull);
  });

  test('la sequenza ripristina la sessione solo dopo readyz', () async {
    final events = <String>[];
    final readiness = Completer<bool>();
    final sequence = StartupSequence(() async => events.add('sessione'));

    final result = sequence.run(
      readiness.future.then((value) {
        events.add('readyz');
        return value;
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    readiness.complete(true);
    expect(await result, isTrue);
    expect(events, ['readyz', 'sessione']);
  });

  test(
    'readyz tardivo non avvia il ripristino del tentativo scaduto',
    () async {
      final readiness = Completer<bool>();
      var restores = 0;
      final sequence = StartupSequence(() async => restores++);

      final expired = sequence.run(readiness.future);
      sequence.expireCurrentAttempt();
      readiness.complete(true);

      expect(await expired, isFalse);
      expect(restores, 0);
      expect(await sequence.run(Future.value(true)), isTrue);
      expect(restores, 1);
    },
  );

  testWidgets('backend subito pronto non mostra la schermata di attesa', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(initial: Future.value(true), retry: () async => true),
    );
    await tester.pump();

    expect(find.text('contenuto app'), findsOneWidget);
    expect(find.byKey(const Key('backendWaitProgress')), findsNothing);
  });

  testWidgets('backend lento mostra e poi chiude subito attesa', (
    tester,
  ) async {
    final readiness = Completer<bool>();
    await tester.pumpWidget(
      _app(initial: readiness.future, retry: () async => true),
    );
    await tester.pump(const Duration(milliseconds: 101));

    expect(find.text('Sto affilando le forbici…'), findsOneWidget);
    expect(find.byKey(const Key('backendWaitProgress')), findsOneWidget);

    readiness.complete(true);
    await tester.pump();
    expect(find.byKey(const Key('backendWaitProgress')), findsNothing);
    expect(find.text('contenuto app'), findsOneWidget);
  });

  testWidgets('timeout mostra Riprova e avvia un solo nuovo tentativo', (
    tester,
  ) async {
    final first = Completer<bool>();
    final second = Completer<bool>();
    var retries = 0;
    await tester.pumpWidget(
      _app(
        initial: first.future,
        timeout: const Duration(milliseconds: 200),
        retry: () {
          retries++;
          return second.future;
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 201));

    expect(find.text('Il salone tarda ad aprire'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backendWaitRetry')));
    await tester.tap(find.byKey(const Key('backendWaitRetry')));
    await tester.pump();
    expect(retries, 1);

    first.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));
    expect(find.byKey(const Key('backendWaitProgress')), findsOneWidget);

    second.complete(true);
    await tester.pump();
    expect(find.text('contenuto app'), findsOneWidget);
  });

  testWidgets('deep link arrivato durante attesa conserva la destinazione', (
    tester,
  ) async {
    final readiness = Completer<bool>();
    var initializations = 0;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) => KeyedSubtree(
            key: const Key('deepLinkTarget'),
            child: _CountingPage(onInitialize: () => initializations++),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.editorial,
        routerConfig: router,
        builder: (context, child) => BackendWaitGate(
          initialAttempt: readiness.future,
          retry: () async => true,
          gracePeriod: const Duration(milliseconds: 100),
          child: child!,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 101));
    router.go('/verify-email?token=abc123');
    await tester.pump();
    expect(find.byKey(const Key('backendWaitProgress')), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/verify-email?token=abc123',
    );
    expect(initializations, 1);

    readiness.complete(true);
    await tester.pump();
    expect(find.text('destinazione'), findsOneWidget);
    expect(initializations, 1);
  });

  testWidgets(
    'il router reale parcheggia e riapre il deep link una sola volta',
    (tester) async {
      final startup = StartupRouteState(complete: false);
      final router = createAppRouter(
        true,
        AuthRepository(),
        startupState: startup,
      );
      addTearDown(router.dispose);
      addTearDown(startup.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.editorial,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      router.go('/verify-email?token=abc123');
      await tester.pump();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/startup');
      expect(startup.pendingLocation, '/verify-email?token=abc123');

      startup.finish();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/verify-email?token=abc123',
      );
      expect(find.text('Verifica email'), findsOneWidget);
    },
  );

  testWidgets('attesa ed errore non vanno in overflow su schermo piccolo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final readiness = Completer<bool>();
    await tester.pumpWidget(
      _app(
        initial: readiness.future,
        retry: () async => false,
        grace: const Duration(milliseconds: 1),
        timeout: const Duration(milliseconds: 200),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(const Key('backendWaitProgress')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('backendWaitRetry')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('backendWaitRetry'))).height,
      52,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('il pannello blocca i tocchi sul contenuto sottostante', (
    tester,
  ) async {
    final readiness = Completer<bool>();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.editorial,
        home: BackendWaitGate(
          initialAttempt: readiness.future,
          retry: () async => true,
          gracePeriod: const Duration(milliseconds: 1),
          child: Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('underlyingAction'),
                onPressed: () => taps++,
                child: const Text('Azione sottostante'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2));

    await tester.tap(
      find.byKey(const Key('underlyingAction')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(taps, 0);
    readiness.complete(true);
    await tester.pump();
  });
}
