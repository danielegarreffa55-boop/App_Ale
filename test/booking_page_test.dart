import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';
import 'package:salon_booking/src/features/appointments/presentation/booking_page.dart';
import 'package:salon_booking/src/providers.dart';

void main() {
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
}
