import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_page.dart';
import '../features/appointments/presentation/appointments_page.dart';
import '../features/appointments/presentation/booking_page.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/account_action_pages.dart';
import '../features/auth/presentation/verification_required_page.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/home/presentation/home_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/privacy_policy_page.dart';
import '../shared/client_shell.dart';
import '../shared/setup_required_page.dart';

GoRouter createAppRouter(bool backendReady, AuthRepository authRepository) {
  return GoRouter(
    refreshListenable: authRepository,
    redirect: (context, state) {
      if (!backendReady) {
        return state.matchedLocation == '/setup' ? null : '/setup';
      }
      if (state.matchedLocation == '/setup') return '/';
      final signedIn = authRepository.currentUser != null;
      final user = authRepository.currentUser;
      final verified =
          user != null &&
          (!user.emailVerificationRequired || user.emailVerified);
      final publicRoute = {
        '/',
        '/verify-email',
        '/reset-password',
        '/privacy',
      }.contains(state.matchedLocation);
      if (!signedIn && !publicRoute) return '/';
      if (signedIn && !verified) {
        final allowed = {'/verify-required', '/verify-email', '/privacy'};
        if (!allowed.contains(state.matchedLocation)) return '/verify-required';
      }
      if (signedIn && verified && state.matchedLocation == '/verify-required') {
        return authRepository.currentUser!.isAdmin ? '/admin' : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupRequiredPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const AuthPage()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/verify-required',
        builder: (context, state) => const VerificationRequiredPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/book',
            builder: (context, state) => const BookingPage(),
          ),
          GoRoute(
            path: '/appointments',
            builder: (context, state) => const AppointmentsPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Pagina non trovata — torna alla home'),
        ),
      ),
    ),
  );
}
