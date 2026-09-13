import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/core/network/backend_api.dart';
import 'package:salon_booking/src/features/appointments/data/appointment_repository.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:salon_booking/src/features/appointments/presentation/booking_page.dart';
import 'package:salon_booking/src/providers.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _AvailabilityRepository extends AppointmentRepository {
  @override
  Future<List<AvailabilitySlot>> availability({
    required String serviceId,
    required DateTime localDay,
  }) async => [
    AvailabilitySlot(
      startAt: localDay.add(const Duration(hours: 10)),
      endAt: localDay.add(const Duration(hours: 10, minutes: 30)),
    ),
  ];
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    await initializeDateFormatting('it_IT');
  });
  test('errore email non verificata è leggibile e non espone lo stack', () {
    const error = ApiException(
      code: 'failed-precondition',
      statusCode: 403,
      message: 'EMAIL_NOT_VERIFIED',
    );

    final message = bookingRequestErrorMessage(error);

    expect(message, 'Verifica l\'email dal link ricevuto, poi riprova.');
    expect(message, isNot(contains('Traceback')));
  });

  testWidgets('prenotazione mostra i servizi dinamici', (tester) async {
    const service = SalonService(
      id: 'taglio',
      name: 'Taglio',
      category: 'Taglio',
      description: 'Consulenza e taglio',
      durationMinutes: 30,
      bufferMinutes: 5,
      priceCents: 3000,
      priceFrom: true,
      active: true,
      displayOrder: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWith((ref) => Stream.value([service])),
        ],
        child: const MaterialApp(home: Scaffold(body: BookingPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taglio'), findsOneWidget);
    expect(find.textContaining('30 min'), findsOneWidget);
    expect(find.textContaining('da '), findsOneWidget);
  });

  testWidgets('data e orario si scelgono separatamente', (tester) async {
    const service = SalonService(
      id: 'taglio',
      name: 'Taglio',
      description: '',
      durationMinutes: 30,
      bufferMinutes: 0,
      active: true,
      displayOrder: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider.overrideWith((ref) => Stream.value([service])),
          studioConfigProvider.overrideWith(
            (ref) => Stream.value(<String, dynamic>{}),
          ),
          appointmentRepositoryProvider.overrideWith(
            (ref) => _AvailabilityRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: BookingPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taglio').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Giorno precedente'), findsOneWidget);
    expect(find.byTooltip('Giorno successivo'), findsOneWidget);
    expect(find.byKey(const Key('bookingTimePickerButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bookingTimePickerButton')));
    await tester.pumpAndSettle();
    expect(find.text('Scegli un orario'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.access_time_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submitBookingButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
