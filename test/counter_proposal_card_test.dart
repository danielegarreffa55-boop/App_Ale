import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:salon_booking/src/shared/appointment_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('it_IT');
  });

  testWidgets('controproposta confronta orario originale e nuovo', (
    tester,
  ) async {
    final appointment = Appointment(
      id: 'a1',
      clientId: 'c1',
      serviceId: 's1',
      serviceName: 'Taglio',
      status: AppointmentStatus.counterProposed,
      requestedStartAt: DateTime.utc(2026, 9, 1, 8),
      requestedEndAt: DateTime.utc(2026, 9, 1, 8, 30),
      proposedStartAt: DateTime.utc(2026, 9, 1, 9),
      proposedEndAt: DateTime.utc(2026, 9, 1, 9, 30),
      createdAt: DateTime.utc(2026, 8, 31),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: appointment,
            onAcceptProposal: () {},
            onRejectProposal: () {},
          ),
        ),
      ),
    );
    expect(find.text('Richiesta originale'), findsOneWidget);
    expect(find.text('Nuova proposta dello studio'), findsOneWidget);
    expect(find.text('Accetta proposta'), findsOneWidget);
    expect(find.text('Rifiuta proposta'), findsOneWidget);
  });
}
