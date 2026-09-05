import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/admin/presentation/admin_day_calendar.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    await initializeDateFormatting('it_IT');
  });

  testWidgets('agenda giornaliera mostra slot, appuntamenti e blocchi', (
    tester,
  ) async {
    final location = tz.getLocation('Europe/Rome');
    final day = tz.TZDateTime(location, 2026, 9, 7);
    final appointmentStart = tz.TZDateTime(location, 2026, 9, 7, 10);
    final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));
    final blockStart = tz.TZDateTime(location, 2026, 9, 7, 12);
    final blockEnd = blockStart.add(const Duration(hours: 1));
    var appointmentOpened = false;
    DateTime? selectedSlot;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            height: 650,
            child: AdminDayCalendar(
              day: day,
              appointments: [
                Appointment(
                  id: 'appointment-1',
                  clientId: 'client-1',
                  serviceId: 'service-1',
                  serviceName: 'Taglio e barba',
                  status: AppointmentStatus.confirmed,
                  requestedStartAt: appointmentStart.toUtc(),
                  requestedEndAt: appointmentEnd.toUtc(),
                  confirmedStartAt: appointmentStart.toUtc(),
                  confirmedEndAt: appointmentEnd.toUtc(),
                  createdAt: appointmentStart.toUtc(),
                  clientName: 'Mario Rossi',
                ),
              ],
              blocks: [
                AgendaBlock(
                  id: 'block-1',
                  startAt: blockStart.toUtc(),
                  endAt: blockEnd.toUtc(),
                  reason: 'Pausa pranzo',
                  active: true,
                ),
              ],
              startHour: 8,
              endHour: 20,
              openingStartMinute: 9 * 60,
              openingEndMinute: 18 * 60,
              onEmptySlotTap: (value) => selectedSlot = value,
              onAppointmentTap: (_) => appointmentOpened = true,
              onBlockTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.textContaining('Pausa pranzo'), findsOneWidget);

    await tester.tap(find.text('Mario Rossi'));
    expect(appointmentOpened, isTrue);

    await tester.tapAt(const Offset(220, 456));
    expect(selectedSlot, isNotNull);
    expect(selectedSlot!.minute % 30, 0);
    expect(tester.takeException(), isNull);
  });
}
