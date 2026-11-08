import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:salon_booking/src/shared/appointment_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    await initializeDateFormatting('it_IT');
  });

  testWidgets('card home affianca ora grande e data su due righe', (
    tester,
  ) async {
    final start = tz.TZDateTime(tz.local, 2026, 11, 12, 15, 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.editorial,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: AppointmentCard(
              prominent: true,
              appointment: Appointment(
                id: 'a1',
                clientId: 'c1',
                serviceId: 's1',
                serviceName: 'Taglio e styling',
                status: AppointmentStatus.confirmed,
                requestedStartAt: start.toUtc(),
                requestedEndAt: start.add(const Duration(minutes: 45)).toUtc(),
                confirmedStartAt: start.toUtc(),
                confirmedEndAt: start.add(const Duration(minutes: 45)).toUtc(),
                createdAt: start.toUtc(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('15:30'), findsOneWidget);
    expect(find.text('Giovedì'), findsOneWidget);
    expect(find.text('12 Novembre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
