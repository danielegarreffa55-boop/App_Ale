import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/admin/presentation/admin_calendar_views.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    await initializeDateFormatting('it_IT');
  });

  testWidgets('le etichette agenda non vengono spezzate su schermi stretti', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.editorial,
        home: Scaffold(
          body: AdminAgendaViewSelector(
            selected: AgendaViewMode.week,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final week = tester.widget<Text>(find.text('Settimana'));
    expect(week.maxLines, 1);
    expect(week.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  Appointment appointment(DateTime start) => Appointment(
    id: 'appointment-1',
    clientId: 'client-1',
    serviceId: 'service-1',
    serviceName: 'Taglio e styling',
    status: AppointmentStatus.confirmed,
    requestedStartAt: start.toUtc(),
    requestedEndAt: start.add(const Duration(minutes: 45)).toUtc(),
    confirmedStartAt: start.toUtc(),
    confirmedEndAt: start.add(const Duration(minutes: 45)).toUtc(),
    createdAt: start.toUtc(),
    clientName: 'Mario Rossi',
  );

  testWidgets('vista settimana mostra griglia temporale e appuntamenti', (
    tester,
  ) async {
    final day = tz.TZDateTime(tz.local, 2026, 9, 7);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.editorial,
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 700,
            child: AdminWeekCalendar(
              selectedDay: day,
              appointments: [appointment(day.add(const Duration(hours: 10)))],
              blocks: const [],
              startHour: 8,
              endHour: 20,
              onEmptySlotTap: (_) {},
              onAppointmentTap: (_) {},
              onBlockTap: (_) {},
              onDayTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('08:00'), findsOneWidget);
    expect(find.textContaining('Mario Rossi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vista mese mostra i giorni e gli appuntamenti', (tester) async {
    final day = tz.TZDateTime(tz.local, 2026, 9, 7);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.editorial,
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 700,
            child: AdminMonthCalendar(
              selectedDay: day,
              appointments: [appointment(day.add(const Duration(hours: 10)))],
              onDayTap: (_) {},
              onAppointmentTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LUN'), findsOneWidget);
    expect(find.textContaining('Mario Rossi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
