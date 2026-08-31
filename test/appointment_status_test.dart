import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/src/features/appointments/domain/appointment_models.dart';

void main() {
  test('la controproposta può essere accettata o rifiutata dal cliente', () {
    expect(
      canTransition(
        AppointmentStatus.counterProposed,
        AppointmentStatus.confirmed,
      ),
      isTrue,
    );
    expect(
      canTransition(
        AppointmentStatus.counterProposed,
        AppointmentStatus.counterRejected,
      ),
      isTrue,
    );
  });

  test('uno stato terminale non può tornare confermato', () {
    expect(
      canTransition(AppointmentStatus.cancelled, AppointmentStatus.confirmed),
      isFalse,
    );
    expect(
      canTransition(AppointmentStatus.rejected, AppointmentStatus.confirmed),
      isFalse,
    );
  });
}
