import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/backend_api.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../domain/appointment_models.dart';

class AppointmentsPage extends ConsumerWidget {
  const AppointmentsPage({super.key});

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla appuntamento'),
        content: const Text(
          'Puoi annullare fino a 24 ore prima. Oltre questo limite contatta '
          'direttamente lo studio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantieni'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma annullamento'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .cancelAppointment(appointment.id);
      ref.invalidate(clientAppointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appuntamento annullato.')),
        );
      }
    } catch (error) {
      final closed =
          error is ApiException &&
          error.message == 'CANCELLATION_WINDOW_CLOSED';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              closed
                  ? 'Mancano meno di 24 ore: contatta direttamente lo studio.'
                  : 'Annullamento non riuscito. Riprova tra poco.',
            ),
          ),
        );
      }
    }
  }

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
                        final cancellable = !{
                          AppointmentStatus.cancelled,
                          AppointmentStatus.rejected,
                          AppointmentStatus.completed,
                        }.contains(item.status);
                        return AppointmentCard(
                          appointment: item,
                          onCancel: cancellable
                              ? () => _cancel(context, ref, item)
                              : null,
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
