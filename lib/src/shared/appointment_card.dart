import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/date_time_x.dart';
import '../features/appointments/domain/appointment_models.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({required this.status, super.key});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.confirmed => Colors.green,
      AppointmentStatus.pendingAdmin => Colors.orange,
      AppointmentStatus.counterProposed => Colors.indigo,
      AppointmentStatus.rejected ||
      AppointmentStatus.counterRejected => Colors.red,
      AppointmentStatus.cancelled => Colors.grey,
      AppointmentStatus.completed => Colors.teal,
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(status.label),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class AdminRequestActions extends StatelessWidget {
  const AdminRequestActions({
    required this.onAccept,
    required this.onReject,
    required this.onCounterPropose,
    this.acceptEnabled = true,
    super.key,
  });

  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCounterPropose;
  final bool acceptEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          key: const Key('adminAcceptButton'),
          onPressed: acceptEnabled ? onAccept : null,
          icon: const Icon(Icons.check),
          label: const Text(AppStrings.accept),
        ),
        OutlinedButton.icon(
          key: const Key('adminRejectButton'),
          onPressed: onReject,
          icon: const Icon(Icons.close),
          label: const Text(AppStrings.reject),
        ),
        FilledButton.tonalIcon(
          key: const Key('adminCounterButton'),
          onPressed: onCounterPropose,
          icon: const Icon(Icons.schedule_send_outlined),
          label: const Text(AppStrings.counterPropose),
        ),
      ],
    );
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    required this.appointment,
    this.onAcceptProposal,
    this.onRejectProposal,
    this.onCancel,
    this.trailing,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback? onAcceptProposal;
  final VoidCallback? onRejectProposal;
  final VoidCallback? onCancel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasProposal =
        appointment.status == AppointmentStatus.counterProposed &&
        appointment.proposedStartAt != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    appointment.serviceName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            AppointmentStatusChip(status: appointment.status),
            const SizedBox(height: 12),
            if (hasProposal) ...[
              _DateBlock(
                title: AppStrings.originalRequest,
                date: appointment.requestedStartAt,
                muted: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.arrow_downward_rounded),
              ),
              _DateBlock(
                title: AppStrings.studioProposal,
                date: appointment.proposedStartAt!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onAcceptProposal,
                      child: const Text(AppStrings.acceptProposal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRejectProposal,
                      child: const Text(AppStrings.rejectProposal),
                    ),
                  ),
                ],
              ),
            ] else
              _DateBlock(
                title: 'Data e ora',
                date: appointment.effectiveStartAt,
              ),
            if (appointment.adminReason case final reason?) ...[
              const SizedBox(height: 12),
              Text('Nota dello studio: $reason'),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Annulla appuntamento'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.title,
    required this.date,
    this.muted = false,
  });
  final String title;
  final DateTime date;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.62 : 1,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(date.italianDateTime),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
