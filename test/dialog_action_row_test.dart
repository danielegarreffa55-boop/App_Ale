import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/shared/dialog_action_row.dart';

void main() {
  testWidgets('le azioni restano affiancate su uno schermo iPhone stretto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Conferma'),
                    actions: [
                      DialogActionRow(
                        cancelLabel: 'Mantieni account',
                        confirmLabel: 'Elimina definitivamente',
                        onCancel: () => Navigator.pop(context),
                        onConfirm: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    final cancel = tester.getCenter(find.text('Mantieni account'));
    final confirm = tester.getCenter(find.text('Elimina definitivamente'));
    expect(cancel.dx, lessThan(confirm.dx));
    expect((cancel.dy - confirm.dy).abs(), lessThan(8));
    expect(tester.takeException(), isNull);
  });
}
