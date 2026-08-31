import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/auth/presentation/auth_page.dart';

void main() {
  testWidgets('login valida i campi obbligatori senza chiamare Firebase', (
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
}
