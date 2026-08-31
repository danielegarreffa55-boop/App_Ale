import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/app.dart';

void main() {
  testWidgets('il calendario si apre con le localizzazioni italiane', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it', 'IT'),
        localizationsDelegates: SalonApp.localizationsDelegates,
        supportedLocales: SalonApp.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 1),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
                locale: const Locale('it', 'IT'),
              ),
              child: const Text('Apri calendario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri calendario'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    final dialogContext = tester.element(find.byType(DatePickerDialog));
    expect(Localizations.localeOf(dialogContext).languageCode, 'it');
    expect(
      MaterialLocalizations.of(dialogContext).cancelButtonLabel,
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
