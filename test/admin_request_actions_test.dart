import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/shared/appointment_card.dart';

void main() {
  testWidgets('admin ha esattamente le tre azioni richieste', (tester) async {
    var action = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminRequestActions(
            onAccept: () => action = 'accept',
            onReject: () => action = 'reject',
            onCounterPropose: () => action = 'counter',
          ),
        ),
      ),
    );
    expect(find.text('Accetta'), findsOneWidget);
    expect(find.text('Rifiuta'), findsOneWidget);
    expect(find.text('Proponi altro orario'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adminCounterButton')));
    expect(action, 'counter');
  });
}
