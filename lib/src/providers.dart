import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/notification_service.dart';
import 'features/appointments/data/appointment_repository.dart';
import 'features/appointments/domain/appointment_models.dart';
import 'features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);
final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return ref.watch(authRepositoryProvider).isAdmin();
});

final servicesProvider = StreamProvider<List<SalonService>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchServices();
});

final adminServicesProvider = StreamProvider<List<SalonService>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchServices(admin: true);
});

final clientAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .watch(appointmentRepositoryProvider)
      .watchClientAppointments(user.uid);
});

final adminAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchAdminAppointments();
});

final clientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchClients();
});
