import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/auth/presentation/auth_page.dart';

void main() {
  testWidgets('login valida i campi obbligatori senza chiamare il backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthPage(checkExistingSession: false)),
      ),
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();
    expect(find.text('Campo obbligatorio'), findsNWidgets(2));
  });

  testWidgets('il pulsante Accedi resta visibile con la tastiera aperta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthPage(checkExistingSession: false)),
      ),
    );

    expect(
      find.byKey(const Key('authSubmitButton')).hitTestable(),
      findsOneWidget,
    );
  });
}
