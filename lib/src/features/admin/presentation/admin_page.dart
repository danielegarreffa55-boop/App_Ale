import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_x.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../../shared/brand_logo.dart';
import '../../appointments/domain/appointment_models.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  var _selected = 0;

  static const _labels = [
    'Dashboard',
    'Richieste',
    'Agenda',
    'Clienti',
    'Servizi',
    'Orari',
    'Impostazioni',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.mark_email_unread_outlined,
    Icons.calendar_month_outlined,
    Icons.people_outline,
    Icons.content_cut_outlined,
    Icons.schedule_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _AccessDenied(error: error),
      data: (allowed) {
        if (!allowed) return const _AccessDenied();
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 980;
        final content = switch (_selected) {
          0 => const _DashboardSection(),
          1 => const _RequestsSection(),
          2 => const _AgendaSection(),
          3 => const _ClientsSection(),
          4 => const _ServicesSection(),
          5 => const _HoursSection(),
          _ => const _SettingsSection(),
        };
        return Scaffold(
          appBar: AppBar(
            title: const BrandWordmark(),
            actions: [
              IconButton(
                tooltip: 'Esci',
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : NavigationDrawer(
                  selectedIndex: _selected,
                  onDestinationSelected: (index) {
                    setState(() => _selected = index);
                    Navigator.pop(context);
                  },
                  children: [
                    const _AdminDrawerHeader(),
                    for (var index = 0; index < _labels.length; index++)
                      NavigationDrawerDestination(
                        icon: Icon(_icons[index]),
                        label: Text(_labels[index]),
                      ),
                  ],
                ),
          body: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: _selected,
                  extended: width >= 1220,
                  labelType: width >= 1220
                      ? NavigationRailLabelType.none
                      : null,
                  onDestinationSelected: (index) =>
                      setState(() => _selected = index),
                  destinations: [
                    for (var index = 0; index < _labels.length; index++)
                      NavigationRailDestination(
                        icon: Icon(_icons[index]),
                        label: Text(_labels[index]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 24 : 12),
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminDrawerHeader extends StatelessWidget {
  const _AdminDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandWordmark(),
          const SizedBox(height: 10),
          Text(
            'Console amministratore',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppTheme.champagne.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text('Accesso amministratore richiesto.'),
                  if (error != null) Text('$error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Torna all\u2019app'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.displaySmall?.copyWith(fontSize: 32),
        ),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      },
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                if (message case final message?) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
                const Spacer(),
                Text(
                  '$value',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAgendaCard extends StatelessWidget {
  const _AdminAgendaCard({required this.appointment, required this.trailing});

  final Appointment appointment;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName ?? 'Cliente',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (appointment.clientPhone case final phone?) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.64,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 14),
            Text(appointment.serviceName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(appointment.effectiveStartAt.italianDateTime),
                  ],
                ),
                AppointmentStatusChip(status: appointment.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminListCard extends StatelessWidget {
  const _AdminListCard({
    required this.icon,
    required this.title,
    this.details = const [],
    this.badge,
    this.badgeActive = true,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> details;
  final String? badge;
  final bool badgeActive;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    for (final detail in details.where(
                      (item) => item.isNotEmpty,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                      ),
                    if (badge case final badge?) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (badgeActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                (badgeActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface)
                                    .withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          badge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: badgeActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.62,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends ConsumerWidget {
  const _DashboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    final clients = ref.watch(clientsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Dashboard',
          subtitle: 'Situazione operativa in tempo reale',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            onRetry: () => ref.invalidate(adminAppointmentsProvider),
            data: (items) {
              final localNow = DateTime.now().inStudioTimezone;
              bool sameDay(DateTime date, int offset) {
                final local = date.inStudioTimezone;
                final target = localNow.add(Duration(days: offset));
                return local.year == target.year &&
                    local.month == target.month &&
                    local.day == target.day;
              }

              final metrics = [
                (
                  'Nuove richieste',
                  items
                      .where((a) => a.status == AppointmentStatus.pendingAdmin)
                      .length,
                  Icons.mark_email_unread_outlined,
                ),
                (
                  'Controproposte',
                  items
                      .where(
                        (a) => a.status == AppointmentStatus.counterProposed,
                      )
                      .length,
                  Icons.swap_horiz_rounded,
                ),
                (
                  'Oggi',
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            sameDay(a.effectiveStartAt, 0),
                      )
                      .length,
                  Icons.today_outlined,
                ),
                (
                  'Domani',
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            sameDay(a.effectiveStartAt, 1),
                      )
                      .length,
                  Icons.event_outlined,
                ),
                ('Clienti', clients.value?.length ?? 0, Icons.people_outline),
                (
                  'Completati',
                  items
                      .where((a) => a.status == AppointmentStatus.completed)
                      .length,
                  Icons.task_alt_outlined,
                ),
              ];
              final upcoming =
                  items
                      .where(
                        (a) =>
                            a.status == AppointmentStatus.confirmed &&
                            a.effectiveStartAt.isAfter(DateTime.now().toUtc()),
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.effectiveStartAt.compareTo(b.effectiveStartAt),
                    );
              return ListView(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 1080
                          ? 5
                          : width >= 760
                          ? 4
                          : width >= 520
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: metrics.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: width < 520 ? 1.4 : 1.5,
                        ),
                        itemBuilder: (context, index) {
                          final metric = metrics[index];
                          return _MetricCard(
                            label: metric.$1,
                            value: metric.$2,
                            icon: metric.$3,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Prossimi appuntamenti',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    const _AdminEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Agenda libera',
                      message: 'Nessun appuntamento confermato in arrivo.',
                    )
                  else
                    ...upcoming
                        .take(8)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppointmentCard(appointment: item),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestsSection extends ConsumerWidget {
  const _RequestsSection();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(adminAppointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Richiesta aggiornata.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    Appointment item,
  ) async {
    final reason = await _textDialog(
      context,
      title: 'Rifiuta richiesta',
      label: 'Motivo facoltativo',
    );
    if (reason == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(appointmentRepositoryProvider)
          .adminReject(item.id, reason: reason.isEmpty ? null : reason),
    );
  }

  Future<void> _counter(
    BuildContext context,
    WidgetRef ref,
    Appointment item,
  ) async {
    final date = await _pickDateTime(context, initial: item.requestedStartAt);
    if (date == null) return;
    if (!context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(appointmentRepositoryProvider)
          .adminCounterPropose(item.id, date),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Richieste',
          subtitle: 'Accetta, rifiuta o proponi direttamente un altro orario',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            onRetry: () => ref.invalidate(adminAppointmentsProvider),
            data: (items) {
              final requests = items
                  .where(
                    (item) =>
                        item.status == AppointmentStatus.pendingAdmin ||
                        item.status == AppointmentStatus.counterProposed ||
                        item.status == AppointmentStatus.counterRejected,
                  )
                  .toList();
              if (requests.isEmpty) {
                return const _AdminEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Tutto sotto controllo',
                  message: 'Non ci sono richieste da gestire.',
                );
              }
              return ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clientName ?? 'Cliente ${item.clientId}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (item.clientPhone case final phone?) Text(phone),
                          const SizedBox(height: 6),
                          Text(
                            '${item.serviceName} · ${item.requestedStartAt.italianDateTime}',
                          ),
                          const SizedBox(height: 12),
                          AppointmentStatusChip(status: item.status),
                          const SizedBox(height: 16),
                          AdminRequestActions(
                            acceptEnabled:
                                item.status == AppointmentStatus.pendingAdmin,
                            onAccept: () => _run(
                              context,
                              ref,
                              () => ref
                                  .read(appointmentRepositoryProvider)
                                  .adminAccept(item.id),
                            ),
                            onReject: () => _reject(context, ref, item),
                            onCounterPropose: () =>
                                _counter(context, ref, item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgendaSection extends ConsumerWidget {
  const _AgendaSection();

  Future<void> _manualAppointment(BuildContext context, WidgetRef ref) async {
    final clients = ref.read(clientsProvider).value ?? const [];
    final services = ref.read(adminServicesProvider).value ?? const [];
    if (clients.isEmpty || services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servono almeno un cliente e un servizio.'),
        ),
      );
      return;
    }
    var clientId = clients.first['id']! as String;
    var serviceId = services.first.id;
    DateTime? startAt;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo appuntamento manuale'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: clientId,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client['id']! as String,
                          child: Text(
                            '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => clientId = value!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: serviceId,
                  decoration: const InputDecoration(labelText: 'Servizio'),
                  items: services
                      .where((service) => service.active)
                      .map(
                        (service) => DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => serviceId = value!,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(startAt?.italianDateTime ?? 'Scegli data e ora'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await _pickDateTime(context);
                    if (picked != null) setDialogState(() => startAt = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: startAt == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Crea e conferma'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || startAt == null) return;
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .adminCreateAppointment(
            clientId: clientId,
            serviceId: serviceId,
            startAt: startAt!,
          );
      ref.invalidate(adminAppointmentsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _createBlock(BuildContext context, WidgetRef ref) async {
    final start = await _pickDateTime(context);
    if (start == null || !context.mounted) return;
    final end = await _pickDateTime(
      context,
      initial: start.add(const Duration(hours: 1)),
    );
    if (end == null || !end.isAfter(start) || !context.mounted) return;
    final reason = await _textDialog(
      context,
      title: 'Motivo blocco',
      label: 'Ferie, pausa, impegno…',
    );
    if (reason == null) return;
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .adminCreateBlock(startAt: start, endAt: end, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Fascia bloccata.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Blocco non riuscito: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(adminAppointmentsProvider);
    ref.watch(clientsProvider);
    ref.watch(adminServicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Agenda',
          subtitle: 'Appuntamenti confermati e blocchi manuali',
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _createBlock(context, ref),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Blocca fascia'),
            ),
            FilledButton.icon(
              onPressed: () => _manualAppointment(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            data: (items) {
              final confirmed =
                  items
                      .where(
                        (item) =>
                            item.status == AppointmentStatus.confirmed &&
                            item.effectiveEndAt.isAfter(DateTime.now().toUtc()),
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.effectiveStartAt.compareTo(b.effectiveStartAt),
                    );
              if (confirmed.isEmpty) {
                return const _AdminEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'Agenda libera',
                  message: 'Non ci sono appuntamenti confermati in arrivo.',
                );
              }
              return ListView.separated(
                itemCount: confirmed.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = confirmed[index];
                  return _AdminAgendaCard(
                    appointment: item,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        try {
                          if (action == 'reschedule') {
                            final startAt = await _pickDateTime(
                              context,
                              initial: item.confirmedStartAt,
                            );
                            if (startAt == null) return;
                            await ref
                                .read(appointmentRepositoryProvider)
                                .adminRescheduleAppointment(item.id, startAt);
                          } else if (action == 'cancel') {
                            await ref
                                .read(appointmentRepositoryProvider)
                                .cancelAppointment(item.id);
                          } else {
                            await ref
                                .read(appointmentRepositoryProvider)
                                .adminCompleteAppointment(item.id);
                          }
                          ref.invalidate(adminAppointmentsProvider);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Operazione non riuscita: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'reschedule',
                          child: Text('Sposta appuntamento'),
                        ),
                        PopupMenuItem(
                          value: 'complete',
                          child: Text('Completato'),
                        ),
                        PopupMenuItem(value: 'cancel', child: Text('Annulla')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClientsSection extends ConsumerStatefulWidget {
  const _ClientsSection();

  @override
  ConsumerState<_ClientsSection> createState() => _ClientsSectionState();
}

class _ClientsSectionState extends ConsumerState<_ClientsSection> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final appointments = ref.watch(adminAppointmentsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Clienti',
          subtitle: 'Ricerca e storico appuntamenti',
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cerca per nome, telefono o email',
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AsyncValueView<List<Map<String, dynamic>>>(
            value: clients,
            data: (items) {
              final filtered = items.where((client) {
                final haystack = [
                  client['firstName'],
                  client['lastName'],
                  client['email'],
                  client['phone'],
                ].join(' ').toLowerCase();
                return haystack.contains(_query);
              }).toList();
              if (filtered.isEmpty) {
                return _AdminEmptyState(
                  icon: Icons.person_search_outlined,
                  title: _query.isEmpty ? 'Nessun cliente' : 'Nessun risultato',
                  message: _query.isEmpty
                      ? 'I nuovi clienti compariranno qui.'
                      : 'Prova con un nome, un telefono o un’email diversi.',
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final client = filtered[index];
                  final visits = appointments
                      .where(
                        (item) =>
                            item.clientId == client['id'] &&
                            item.status == AppointmentStatus.completed,
                      )
                      .length;
                  final name =
                      '${client['firstName'] ?? ''} ${client['lastName'] ?? ''}'
                          .trim();
                  return _AdminListCard(
                    icon: Icons.person_outline,
                    title: name.isEmpty ? 'Cliente' : name,
                    details: [
                      '${client['phone'] ?? ''}',
                      '${client['email'] ?? ''}',
                    ],
                    badge: visits == 1 ? '1 visita' : '$visits visite',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  const _ServicesSection();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SalonService? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name);
    final description = TextEditingController(text: existing?.description);
    final duration = TextEditingController(
      text: '${existing?.durationMinutes ?? 30}',
    );
    final buffer = TextEditingController(
      text: '${existing?.bufferMinutes ?? 0}',
    );
    final price = TextEditingController(
      text: existing?.priceCents == null
          ? ''
          : (existing!.priceCents! / 100).toStringAsFixed(2),
    );
    var active = existing?.active ?? true;
    final result = await showDialog<SalonService>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Nuovo servizio' : 'Modifica servizio',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durata (min)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: buffer,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Buffer (min)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Prezzo EUR'),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('Prenotabile'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final durationValue = int.tryParse(duration.text);
                if (name.text.trim().isEmpty || durationValue == null) return;
                final priceValue = double.tryParse(
                  price.text.replaceAll(',', '.'),
                );
                Navigator.pop(
                  dialogContext,
                  SalonService(
                    id: existing?.id ?? '',
                    name: name.text,
                    description: description.text,
                    durationMinutes: durationValue,
                    bufferMinutes: int.tryParse(buffer.text) ?? 0,
                    priceCents: priceValue == null
                        ? null
                        : (priceValue * 100).round(),
                    active: active,
                    displayOrder: existing?.displayOrder ?? 100,
                  ),
                );
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    duration.dispose();
    buffer.dispose();
    price.dispose();
    if (result == null) return;
    await ref.read(appointmentRepositoryProvider).saveService(result);
    ref.invalidate(adminServicesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(adminServicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Servizi',
          subtitle: 'Durata, buffer, prezzo e visibilità',
          actions: [
            FilledButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo servizio'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AsyncValueView<List<SalonService>>(
            value: services,
            data: (items) {
              if (items.isEmpty) {
                return const _AdminEmptyState(
                  icon: Icons.content_cut_outlined,
                  title: 'Nessun servizio',
                  message: 'Crea il primo servizio prenotabile.',
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final service = items[index];
                  final price = service.priceCents == null
                      ? 'Prezzo su richiesta'
                      : NumberFormat.simpleCurrency(locale: 'it_IT')
                            .format(service.priceCents! / 100);
                  final timing = service.bufferMinutes > 0
                      ? '${service.durationMinutes} min · ${service.bufferMinutes} min di pausa'
                      : '${service.durationMinutes} min';
                  return _AdminListCard(
                    icon: service.active
                        ? Icons.content_cut_outlined
                        : Icons.hide_source_outlined,
                    title: service.name,
                    details: [
                      if (service.description.trim().isNotEmpty)
                        service.description,
                      '$timing · $price',
                    ],
                    badge: service.active ? 'Prenotabile' : 'Nascosto',
                    badgeActive: service.active,
                    trailing: IconButton(
                      tooltip: 'Modifica servizio',
                      onPressed: () => _edit(context, ref, service),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HoursSection extends StatelessWidget {
  const _HoursSection();
  static const _days = <String, String>{
    'monday': 'Lunedì',
    'tuesday': 'Martedì',
    'wednesday': 'Mercoledì',
    'thursday': 'Giovedì',
    'friday': 'Venerdì',
    'saturday': 'Sabato',
    'sunday': 'Domenica',
  };

  Future<void> _editDay(
    BuildContext context,
    String key,
    String label,
    Map<String, dynamic> current,
    Map<String, dynamic> allHours,
  ) async {
    var enabled = current['enabled'] as bool? ?? false;
    var open = current['open'] as String? ?? '09:00';
    var close = current['close'] as String? ?? '18:00';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
                title: const Text('Giorno lavorativo'),
              ),
              ListTile(
                title: const Text('Apertura'),
                trailing: Text(open),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(open),
                  );
                  if (picked != null) {
                    setDialogState(() => open = _formatTime(picked));
                  }
                },
              ),
              ListTile(
                title: const Text('Chiusura'),
                trailing: Text(close),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(close),
                  );
                  if (picked != null) {
                    setDialogState(() => close = _formatTime(picked));
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await FirebaseFirestore.instance.collection('studio').doc('config').set({
      'openingHours': {
        ...allHours,
        key: {'enabled': enabled, 'open': open, 'close': close, 'breaks': []},
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          'Orari',
          subtitle: 'Settimana standard; ferie e chiusure si gestiscono dai blocchi agenda',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('studio')
                .doc('config')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final hours = Map<String, dynamic>.from(
                snapshot.data!.data()?['openingHours'] as Map? ?? const {},
              );
              return ListView(
                children: _days.entries.map((entry) {
                  final day = Map<String, dynamic>.from(
                    hours[entry.key] as Map? ?? const {},
                  );
                  final enabled = day['enabled'] as bool? ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AdminListCard(
                      icon: enabled
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_outlined,
                      title: entry.value,
                      details: [
                        enabled
                            ? '${day['open'] ?? '09:00'} – ${day['close'] ?? '18:00'}'
                            : 'Nessun orario configurato',
                      ],
                      badge: enabled ? 'Aperto' : 'Chiuso',
                      badgeActive: enabled,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _editDay(context, entry.key, entry.value, day, hours),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection();

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final _studioName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _reminder = TextEditingController();
  var _loaded = false;

  @override
  void dispose() {
    _studioName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _reminder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('studio').doc('config').set({
      'studioName': _studioName.text.trim(),
      'supportEmail': _email.text.trim(),
      'supportPhone': _phone.text.trim(),
      'address': _address.text.trim(),
      'timezone': AppConfig.timezone,
      'currency': AppConfig.currency,
      'reminderTime': _reminder.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impostazioni salvate.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('studio')
          .doc('config')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_loaded) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          _studioName.text =
              data['studioName'] as String? ?? AppConfig.studioName;
          _email.text =
              data['supportEmail'] as String? ?? AppConfig.supportEmail;
          _phone.text =
              data['supportPhone'] as String? ?? AppConfig.supportPhone;
          _address.text = data['address'] as String? ?? AppConfig.address;
          _reminder.text =
              data['reminderTime'] as String? ?? AppConfig.reminderTime;
          _loaded = true;
        }
        return ListView(
          children: [
            const _SectionHeader(
              'Impostazioni',
              subtitle: 'Brand, contatti e promemoria',
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Dati dello studio',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _studioName,
                          decoration: const InputDecoration(
                            labelText: 'Nome studio',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Email supporto',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefono',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _address,
                          decoration: const InputDecoration(
                            labelText: 'Indirizzo',
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Automazioni',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reminder,
                          decoration: const InputDecoration(
                            labelText: 'Promemoria giorno prima (HH:mm)',
                            helperText: 'Timezone Europe/Rome',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text(AppStrings.save),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text(AppStrings.confirm),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<DateTime?> _pickDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final localInitial =
      initial?.inStudioTimezone ?? DateTime.now().add(const Duration(days: 1));
  final now = DateUtils.dateOnly(DateTime.now());
  final day = await showDatePicker(
    context: context,
    initialDate: DateTime(
      localInitial.year,
      localInitial.month,
      localInitial.day,
    ),
    firstDate: now,
    lastDate: now.add(const Duration(days: 730)),
    locale: const Locale('it', 'IT'),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: localInitial.hour,
      minute: localInitial.minute,
    ),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 9,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
