import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';

void main() {
  final requestStart = DateTime.utc(2026, 9, 7, 10);
  final requestEnd = DateTime.utc(2026, 9, 7, 10, 45);
  final appointment = Appointment(
    id: 'appointment-1',
    clientId: 'client-1',
    serviceId: 'service-1',
    serviceName: 'Taglio e barba',
    status: AppointmentStatus.pendingAdmin,
    requestedStartAt: requestStart,
    requestedEndAt: requestEnd,
    createdAt: requestStart,
  );

  AgendaBlock block({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
    bool active = true,
  }) => AgendaBlock(
    id: id,
    startAt: startAt,
    endAt: endAt,
    reason: 'Pausa privata',
    active: active,
  );

  test('segnala un blocco attivo sovrapposto alla richiesta', () {
    final conflict = findAgendaBlockConflict(appointment, [
      block(
        id: 'overlap',
        startAt: DateTime.utc(2026, 9, 7, 10, 30),
        endAt: DateTime.utc(2026, 9, 7, 11),
      ),
    ]);

    expect(conflict?.id, 'overlap');
  });

  test('non segnala blocchi adiacenti o disattivati', () {
    final conflict = findAgendaBlockConflict(appointment, [
      block(
        id: 'adjacent',
        startAt: requestEnd,
        endAt: DateTime.utc(2026, 9, 7, 11, 30),
      ),
      block(
        id: 'inactive',
        startAt: requestStart,
        endAt: requestEnd,
        active: false,
      ),
    ]);

    expect(conflict, isNull);
  });

  test('segnala gli appuntamenti confermati sovrapposti', () {
    final confirmed = Appointment(
      id: 'confirmed-1',
      clientId: 'client-2',
      serviceId: 'service-1',
      serviceName: 'Taglio',
      status: AppointmentStatus.confirmed,
      requestedStartAt: DateTime.utc(2026, 9, 7, 10, 30),
      requestedEndAt: DateTime.utc(2026, 9, 7, 11),
      confirmedStartAt: DateTime.utc(2026, 9, 7, 10, 30),
      confirmedEndAt: DateTime.utc(2026, 9, 7, 11),
      createdAt: requestStart,
      clientName: 'Mario Rossi',
    );

    final conflicts = findConfirmedAppointmentConflicts(appointment, [
      appointment,
      confirmed,
    ]);

    expect(conflicts.map((item) => item.id), ['confirmed-1']);
  });

  test('ignora richieste pendenti e appuntamenti adiacenti', () {
    final adjacent = Appointment(
      id: 'confirmed-adjacent',
      clientId: 'client-2',
      serviceId: 'service-1',
      serviceName: 'Taglio',
      status: AppointmentStatus.confirmed,
      requestedStartAt: requestEnd,
      requestedEndAt: DateTime.utc(2026, 9, 7, 11, 15),
      confirmedStartAt: requestEnd,
      confirmedEndAt: DateTime.utc(2026, 9, 7, 11, 15),
      createdAt: requestStart,
    );
    final pending = Appointment(
      id: 'pending-overlap',
      clientId: 'client-3',
      serviceId: 'service-1',
      serviceName: 'Taglio',
      status: AppointmentStatus.pendingAdmin,
      requestedStartAt: requestStart,
      requestedEndAt: requestEnd,
      createdAt: requestStart,
    );

    final conflicts = findConfirmedAppointmentConflicts(appointment, [
      adjacent,
      pending,
    ]);

    expect(conflicts, isEmpty);
  });
}
