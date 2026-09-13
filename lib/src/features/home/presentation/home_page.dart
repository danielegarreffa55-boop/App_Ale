import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../appointments/domain/appointment_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _resendVerification(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).resendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email di verifica inviata.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invio non riuscito. Riprova tra poco.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(clientAppointmentsProvider);
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName;
    final firstName = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').first
        : null;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(clientAppointmentsProvider),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciao${firstName == null ? '' : ', $firstName'}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Benvenuto da ${AppConfig.studioName}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (user != null && !user.emailVerified) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: const Text('Verifica il tuo indirizzo email'),
                      subtitle: const Text(
                        'Apri il link che ti abbiamo inviato per proteggere il tuo account.',
                      ),
                      trailing: TextButton(
                        onPressed: () => _resendVerification(context, ref),
                        child: const Text('Reinvia'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Il tuo prossimo appuntamento',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/book'),
                      icon: const Icon(Icons.add),
                      label: const Text('Prenota'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AsyncValueView<List<Appointment>>(
                  value: appointments,
                  onRetry: () => ref.invalidate(clientAppointmentsProvider),
                  data: (items) {
                    final now = DateTime.now().toUtc();
                    final upcoming =
                        items
                            .where(
                              (item) =>
                                  item.effectiveEndAt.isAfter(now) &&
                                  item.status != AppointmentStatus.rejected &&
                                  item.status != AppointmentStatus.cancelled &&
                                  item.status !=
                                      AppointmentStatus.counterRejected,
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.effectiveStartAt.compareTo(
                              b.effectiveStartAt,
                            ),
                          );
                    if (upcoming.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              const Text('Nessun appuntamento in programma.'),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => context.go('/book'),
                                child: const Text('Scegli un servizio'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return AppointmentCard(appointment: upcoming.first);
                  },
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(AppConfig.address),
                    subtitle: Text(AppConfig.supportPhone),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
