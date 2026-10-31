import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../appointments/domain/appointment_models.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  decoration: BoxDecoration(
                    color: AppTheme.chrome,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ciao${firstName == null ? '' : ', $firstName'}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Benvenuto da ${AppConfig.studioName}.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PROSSIMO APPUNTAMENTO',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.muted,
                          letterSpacing: 1.2,
                        ),
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
                      return SizedBox(
                        width: double.infinity,
                        child: Card(
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
                        ),
                      );
                    }
                    return AppointmentCard(
                      appointment: upcoming.first,
                      prominent: true,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'LO STUDIO',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppTheme.subtle, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Card(
                  color: AppTheme.chrome,
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.accent,
                    ),
                    title: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppConfig.address.replaceAll(' ', '\u00A0'),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
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
