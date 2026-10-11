import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salon_booking/src/core/notifications/notification_service.dart';
import 'package:salon_booking/src/features/appointments/data/appointment_repository.dart';
import 'package:salon_booking/src/features/auth/data/auth_repository.dart';
import 'package:salon_booking/src/providers.dart';
import 'package:salon_booking/src/shared/client_shell.dart';

class _AuthRepository extends AuthRepository {
  static const user = AuthUser(
    uid: 'client',
    email: 'cliente@example.it',
    firstName: 'Mario',
    lastName: 'Rossi',
    phone: '',
    role: 'client',
    emailVerified: true,
    emailVerificationRequired: true,
  );

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);
}

class _NotificationService extends NotificationService {
  @override
  Future<bool> firstPromptWasShown(String userId) async => true;

  @override
  Future<bool?> permissionEnabled() async => true;
}

class _AppointmentRepository extends AppointmentRepository {
  @override
  Future<Map<String, dynamic>> fetchStudioConfig() async => {
    'announcement': {
      'id': 'ferie-2026',
      'title': 'Chiusura estiva',
      'message': 'Lo studio resterà chiuso dal 10 al 20 agosto.',
      'active': true,
    },
  };
}

void main() {
  testWidgets(
    'mostra l’annuncio anche aprendo una sezione diversa dalla home',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ClientShell(child: Text('Profilo')),
          ),
        ],
      );
      final auth = _AuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            notificationServiceProvider.overrideWithValue(
              _NotificationService(),
            ),
            appointmentRepositoryProvider.overrideWithValue(
              _AppointmentRepository(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chiusura estiva'), findsOneWidget);
      expect(
        find.text('Lo studio resterà chiuso dal 10 al 20 agosto.'),
        findsOneWidget,
      );
    },
  );
}
