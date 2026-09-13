import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'features/appointments/data/appointment_repository.dart';
import 'features/appointments/domain/appointment_models.dart';
import 'features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository.instance,
);
final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return ref.watch(authRepositoryProvider).isAdmin();
});

final isOwnerProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return ref.watch(authRepositoryProvider).isOwner();
});

final servicesProvider = StreamProvider.autoDispose<List<SalonService>>((ref) {
  return ref.watch(appointmentRepositoryProvider).watchServices();
});

final adminServicesProvider = StreamProvider.autoDispose<List<SalonService>>((
  ref,
) {
  return ref.watch(appointmentRepositoryProvider).watchServices(admin: true);
});

final clientAppointmentsProvider =
    StreamProvider.autoDispose<List<Appointment>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const Stream.empty();
      return ref
          .watch(appointmentRepositoryProvider)
          .watchClientAppointments(user.uid);
    });

final adminAppointmentsProvider = StreamProvider.autoDispose<List<Appointment>>(
  (ref) {
    return ref.watch(appointmentRepositoryProvider).watchAdminAppointments();
  },
);

typedef AdminAgendaRange = ({DateTime startAt, DateTime endAt});

final adminAgendaProvider = StreamProvider.autoDispose
    .family<List<Appointment>, AdminAgendaRange>((ref, range) {
      return ref
          .watch(appointmentRepositoryProvider)
          .watchAdminAgenda(startAt: range.startAt, endAt: range.endAt);
    });

final adminBlocksProvider = StreamProvider.autoDispose<List<AgendaBlock>>((
  ref,
) {
  return ref.watch(appointmentRepositoryProvider).watchAdminBlocks();
});

final studioConfigProvider = StreamProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(appointmentRepositoryProvider).watchStudioConfig();
});

final clientsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(appointmentRepositoryProvider).watchClients();
});
