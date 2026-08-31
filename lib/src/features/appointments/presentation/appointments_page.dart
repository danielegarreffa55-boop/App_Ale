import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../domain/appointment_models.dart';

class AppointmentsPage extends ConsumerWidget {
  const AppointmentsPage({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    bool accept,
  ) async {
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .clientRespondToCounterProposal(appointment.id, accept: accept);
      ref.invalidate(clientAppointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Proposta accettata. Lo slot è stato ricontrollato e confermato.'
                  : 'Proposta rifiutata. Lo studio è stato avvisato.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(clientAppointmentsProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.appointments,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AsyncValueView<List<Appointment>>(
                  value: appointments,
                  onRetry: () => ref.invalidate(clientAppointmentsProvider),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(AppStrings.noAppointments),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return AppointmentCard(
                          appointment: item,
                          onAcceptProposal:
                              item.status == AppointmentStatus.counterProposed
                              ? () => _respond(context, ref, item, true)
                              : null,
                          onRejectProposal:
                              item.status == AppointmentStatus.counterProposed
                              ? () => _respond(context, ref, item, false)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
