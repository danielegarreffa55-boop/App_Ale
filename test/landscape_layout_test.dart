import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/auth/presentation/auth_page.dart';
import 'package:salon_booking/src/shared/client_shell.dart';

void _useLandscapePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
}

void main() {
  testWidgets('la navigazione cliente diventa laterale in landscape', (
    tester,
  ) async {
    _useLandscapePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const ClientShell(
            child: SingleChildScrollView(
              child: SizedBox(height: 700, child: Text('Contenuto cliente')),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.editorial,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Contenuto cliente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accesso resta scorrevole e utilizzabile in landscape', (
    tester,
  ) async {
    _useLandscapePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthPage(checkExistingSession: false)),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('authSubmitButton')),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const Key('authSubmitButton')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
