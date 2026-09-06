import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_x.dart';
import '../../../providers.dart';
import '../../../shared/appointment_card.dart';
import '../../../shared/async_value_view.dart';
import '../../../shared/brand_logo.dart';
import '../../appointments/domain/appointment_models.dart';
import 'admin_day_calendar.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  var _selected = 0;
  var _agendaInitialDayOffset = 0;

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

  void _selectSection(int index, {int agendaDayOffset = 0}) {
    setState(() {
      _selected = index;
      if (index == 2) _agendaInitialDayOffset = agendaDayOffset;
    });
  }

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
          0 => _DashboardSection(
            onNavigate: (section, agendaDayOffset) =>
                _selectSection(section, agendaDayOffset: agendaDayOffset),
          ),
          1 => const _RequestsSection(),
          2 => _AgendaSection(
            key: ValueKey(_agendaInitialDayOffset),
            initialDayOffset: _agendaInitialDayOffset,
          ),
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
                    _selectSection(index);
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
                  onDestinationSelected: _selectSection,
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
                ?.copyWith(color: AppTheme.ink.withValues(alpha: 0.62)),
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
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
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
  const _DashboardSection({required this.onNavigate});

  final void Function(int section, int agendaDayOffset) onNavigate;

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
                  1,
                  0,
                ),
                (
                  'Controproposte',
                  items
                      .where(
                        (a) => a.status == AppointmentStatus.counterProposed,
                      )
                      .length,
                  Icons.swap_horiz_rounded,
                  1,
                  0,
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
                  2,
                  0,
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
                  2,
                  1,
                ),
                (
                  'Clienti',
                  clients.value?.length ?? 0,
                  Icons.people_outline,
                  3,
                  0,
                ),
                (
                  'Completati',
                  items
                      .where((a) => a.status == AppointmentStatus.completed)
                      .length,
                  Icons.task_alt_outlined,
                  2,
                  0,
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
                            onTap: () => onNavigate(metric.$4, metric.$5),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prossimi appuntamenti',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onNavigate(2, 0),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Apri agenda'),
                      ),
                    ],
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
    final blocks =
        ref.watch(adminBlocksProvider).value ?? const <AgendaBlock>[];
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
                  final conflictingBlock = findAgendaBlockConflict(
                    item,
                    blocks,
                  );
                  final appointmentConflicts =
                      findConfirmedAppointmentConflicts(item, items);
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
                          if (conflictingBlock != null) ...[
                            const SizedBox(height: 14),
                            _BlockConflictWarning(block: conflictingBlock),
                          ],
                          if (appointmentConflicts.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _AppointmentConflictWarning(
                              appointments: appointmentConflicts,
                            ),
                          ],
                          const SizedBox(height: 12),
                          AppointmentStatusChip(status: item.status),
                          const SizedBox(height: 16),
                          AdminRequestActions(
                            acceptEnabled:
                                item.status == AppointmentStatus.pendingAdmin &&
                                appointmentConflicts.isEmpty,
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

class _BlockConflictWarning extends StatelessWidget {
  const _BlockConflictWarning({required this.block});

  final AgendaBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warningColor = Colors.orange.shade300;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warningColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attenzione: coincide con un blocco agenda',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warningColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(block.reason),
                const SizedBox(height: 2),
                Text(
                  '${block.startAt.italianDateTime} – '
                  '${DateFormat('HH:mm').format(block.endAt.inStudioTimezone)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
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

class _AppointmentConflictWarning extends StatelessWidget {
  const _AppointmentConflictWarning({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warningColor = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warningColor.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_outlined, color: warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointments.length == 1
                      ? 'Attenzione: orario già occupato'
                      : 'Attenzione: più appuntamenti sovrapposti',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warningColor,
                  ),
                ),
                const SizedBox(height: 6),
                for (final appointment in appointments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${appointment.clientName ?? 'Cliente'} · '
                      '${appointment.serviceName}\n'
                      '${appointment.effectiveStartAt.italianDateTime} – '
                      '${appointment.effectiveEndAt.italianTime}',
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Libera la fascia oppure proponi un altro orario prima di confermare.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
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

class _AgendaSection extends ConsumerStatefulWidget {
  const _AgendaSection({super.key, this.initialDayOffset = 0});

  final int initialDayOffset;

  @override
  ConsumerState<_AgendaSection> createState() => _AgendaSectionState();
}

class _AgendaSectionState extends ConsumerState<_AgendaSection> {
  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().inStudioTimezone;
    _selectedDay = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: widget.initialDayOffset));
  }

  Future<void> _manualAppointment(
    BuildContext context, {
    DateTime? initialStartAt,
  }) async {
    final clients = ref.read(clientsProvider).value ?? const [];
    final services = ref.read(adminServicesProvider).value ?? const [];
    final activeServices = services.where((service) => service.active).toList();
    if (clients.isEmpty || activeServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servono almeno un cliente e un servizio.'),
        ),
      );
      return;
    }
    var clientId = clients.first['id']! as String;
    var serviceId = activeServices.first.id;
    DateTime? startAt = initialStartAt;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo appuntamento'),
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
                  items: activeServices
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
                    final picked = await _pickDateTime(
                      context,
                      initial: startAt,
                    );
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
      final localStart = startAt!.inStudioTimezone;
      if (mounted) {
        setState(
          () => _selectedDay = DateTime(
            localStart.year,
            localStart.month,
            localStart.day,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Creazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _createBlock(
    BuildContext context, {
    DateTime? initialStartAt,
  }) async {
    final start = await _pickDateTime(context, initial: initialStartAt);
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
      ref.invalidate(adminBlocksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Blocco agenda salvato. I clienti possono ancora richiedere la fascia.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Blocco non riuscito: $error')));
      }
    }
  }

  Future<void> _pickAgendaDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = DateUtils.dateOnly(picked));
    }
  }

  DateTime _suggestedStart(int? openingStartMinute, int? openingEndMinute) {
    final now = DateTime.now().inStudioTimezone;
    final today = _sameCalendarDay(_selectedDay, now);
    var minute = openingStartMinute ?? 9 * 60;
    if (today) minute = ((now.hour * 60 + now.minute + 29) ~/ 30) * 30;
    if (openingStartMinute != null && minute < openingStartMinute) {
      minute = openingStartMinute;
    }
    if (openingEndMinute != null && minute >= openingEndMinute) {
      minute = openingEndMinute - 30;
    }
    final hour = minute ~/ 60;
    final minuteOfHour = minute % 60;
    return tz.TZDateTime(
      tz.getLocation(AppConfig.timezone),
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      hour,
      minuteOfHour,
    );
  }

  ({int? start, int? end}) _openingWindow(Map<String, dynamic> config) {
    final hours = Map<String, dynamic>.from(
      config['openingHours'] as Map? ?? const {},
    );
    final rawDay = hours[_dayKeys[_selectedDay.weekday - 1]] as Map?;
    if (rawDay == null) {
      return _selectedDay.weekday == DateTime.sunday
          ? (start: null, end: null)
          : (start: 9 * 60, end: 18 * 60);
    }
    final day = Map<String, dynamic>.from(rawDay);
    if ((day['enabled'] as bool?) != true) return (start: null, end: null);
    return (
      start: _minutes(day['open'] as String? ?? '09:00'),
      end: _minutes(day['close'] as String? ?? '18:00'),
    );
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return (int.tryParse(parts.first) ?? 9) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  AdminAgendaRange get _agendaRange {
    final location = tz.getLocation(AppConfig.timezone);
    final start = tz.TZDateTime(
      location,
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final end = tz.TZDateTime(
      location,
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + 1,
    );
    return (startAt: start.toUtc(), endAt: end.toUtc());
  }

  Future<void> _openAppointment(Appointment item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.clientName ?? 'Cliente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(item.serviceName),
              Text(item.effectiveStartAt.italianDateTime),
              if (item.clientPhone case final phone?) Text(phone),
              const SizedBox(height: 16),
              AppointmentStatusChip(status: item.status),
              if (item.status == AppointmentStatus.confirmed) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('Sposta appuntamento'),
                  onTap: () => Navigator.pop(sheetContext, 'reschedule'),
                ),
                ListTile(
                  leading: const Icon(Icons.task_alt_outlined),
                  title: const Text('Segna come completato'),
                  onTap: () => Navigator.pop(sheetContext, 'complete'),
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Annulla appuntamento'),
                  onTap: () => Navigator.pop(sheetContext, 'cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    }
  }

  Future<void> _openBlock(AgendaBlock block) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fascia bloccata',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(block.reason),
              const SizedBox(height: 6),
              Text(
                '${block.startAt.italianDateTime} – ${block.endAt.italianTime}',
              ),
              const SizedBox(height: 12),
              Text(
                'I clienti possono comunque richiedere questo orario: '
                'riceverai un avviso nella sezione Richieste.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(adminAgendaProvider(_agendaRange));
    final blocks = ref.watch(adminBlocksProvider);
    final studioConfig = ref.watch(studioConfigProvider).value ?? const {};
    ref.watch(clientsProvider);
    ref.watch(adminServicesProvider);
    final opening = _openingWindow(studioConfig);
    final startHour = opening.start == null || opening.start! ~/ 60 >= 8
        ? 8
        : opening.start! ~/ 60;
    final closingHour = opening.end == null ? 20 : (opening.end! / 60).ceil();
    final endHour = closingHour <= 20 ? 20 : closingHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Agenda',
          subtitle: 'Calendario giornaliero e gestione degli slot',
          actions: [
            FilledButton.tonalIcon(
              onPressed: () => _createBlock(
                context,
                initialStartAt: _suggestedStart(opening.start, opening.end),
              ),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Blocca fascia'),
            ),
            FilledButton.icon(
              onPressed: () => _manualAppointment(
                context,
                initialStartAt: _suggestedStart(opening.start, opening.end),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AgendaDateToolbar(
          day: _selectedDay,
          onPrevious: () => setState(
            () => _selectedDay = _selectedDay.subtract(const Duration(days: 1)),
          ),
          onNext: () => setState(
            () => _selectedDay = _selectedDay.add(const Duration(days: 1)),
          ),
          onPickDate: () => _pickAgendaDay(context),
          onToday: () {
            final today = DateTime.now().inStudioTimezone;
            setState(
              () => _selectedDay = DateTime(today.year, today.month, today.day),
            );
          },
        ),
        const SizedBox(height: 10),
        const _AgendaLegend(),
        const SizedBox(height: 10),
        Expanded(
          child: AsyncValueView<List<Appointment>>(
            value: appointments,
            onRetry: () => ref.invalidate(adminAgendaProvider(_agendaRange)),
            data: (items) {
              final calendarItems =
                  items
                      .where(
                        (item) =>
                            item.status == AppointmentStatus.confirmed ||
                            item.status == AppointmentStatus.completed,
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          a.effectiveStartAt.compareTo(b.effectiveStartAt),
                    );
              return AsyncValueView<List<AgendaBlock>>(
                value: blocks,
                onRetry: () => ref.invalidate(adminBlocksProvider),
                data: (dayBlocks) => AdminDayCalendar(
                  day: _selectedDay,
                  appointments: calendarItems,
                  blocks: dayBlocks,
                  startHour: startHour,
                  endHour: endHour,
                  openingStartMinute: opening.start,
                  openingEndMinute: opening.end,
                  onEmptySlotTap: (startAt) =>
                      _manualAppointment(context, initialStartAt: startAt),
                  onAppointmentTap: _openAppointment,
                  onBlockTap: _openBlock,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgendaDateToolbar extends StatelessWidget {
  const _AgendaDateToolbar({
    required this.day,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onToday,
  });

  final DateTime day;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(day);
    final label = formatted.isEmpty
        ? formatted
        : '${formatted[0].toUpperCase()}${formatted.substring(1)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Giorno precedente',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Giorno successivo',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            IconButton(
              tooltip: 'Vai a oggi',
              onPressed: onToday,
              icon: const Icon(Icons.today_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaLegend extends StatelessWidget {
  const _AgendaLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(color: theme.colorScheme.primary, label: 'Appuntamento'),
        _LegendItem(color: theme.colorScheme.outline, label: 'Blocco'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
            const SizedBox(width: 5),
            Text(
              'Tocca uno slot libero per prenotare',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

bool _sameCalendarDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

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
    final category = TextEditingController(
      text: existing?.category ?? 'Altri servizi',
    );
    final description = TextEditingController(text: existing?.description);
    final duration = TextEditingController(
      text: '${existing?.durationMinutes ?? 30}',
    );
    final price = TextEditingController(
      text: existing?.priceCents == null
          ? ''
          : (existing!.priceCents! / 100).toStringAsFixed(2),
    );
    var active = existing?.active ?? true;
    var priceFrom = existing?.priceFrom ?? false;
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
                    controller: category,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      hintText: 'Taglio, Colore, Trattamenti…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrizione'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durata (min)',
                    ),
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
                    value: priceFrom,
                    onChanged: (value) =>
                        setDialogState(() => priceFrom = value),
                    title: const Text('Mostra “a partire da”'),
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
                    category: category.text.trim().isEmpty
                        ? 'Altri servizi'
                        : category.text,
                    description: description.text,
                    durationMinutes: durationValue,
                    bufferMinutes: 0,
                    priceCents: priceValue == null
                        ? null
                        : (priceValue * 100).round(),
                    priceFrom: priceFrom,
                    operatorIds: existing?.operatorIds ?? const ['alessio'],
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
    category.dispose();
    description.dispose();
    duration.dispose();
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
          subtitle: 'Categorie, durata, prezzo e visibilità',
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
                      : '${service.priceFrom ? 'Da ' : ''}'
                            '${NumberFormat.simpleCurrency(locale: 'it_IT').format(service.priceCents! / 100)}';
                  final timing = '${service.durationMinutes} min';
                  return _AdminListCard(
                    icon: service.active
                        ? Icons.content_cut_outlined
                        : Icons.hide_source_outlined,
                    title: service.name,
                    details: [
                      if (service.description.trim().isNotEmpty)
                        service.description,
                      service.category,
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
  final _slotMinutes = TextEditingController();
  final _minimumLeadMinutes = TextEditingController();
  final _bookingHorizonDays = TextEditingController();
  final _cancellationNoticeHours = TextEditingController();
  var _loaded = false;

  @override
  void dispose() {
    _studioName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _reminder.dispose();
    _slotMinutes.dispose();
    _minimumLeadMinutes.dispose();
    _bookingHorizonDays.dispose();
    _cancellationNoticeHours.dispose();
    super.dispose();
  }

  int _setting(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value >= 0 ? value : fallback;
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
      'slotMinutes': _setting(_slotMinutes, 30).clamp(5, 120),
      'minimumLeadMinutes': _setting(_minimumLeadMinutes, 120).clamp(0, 43200),
      'bookingHorizonDays': _setting(_bookingHorizonDays, 90).clamp(1, 730),
      'cancellationNoticeHours': _setting(
        _cancellationNoticeHours,
        24,
      ).clamp(0, 720),
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
          _slotMinutes.text = '${(data['slotMinutes'] as num?)?.toInt() ?? 30}';
          _minimumLeadMinutes.text =
              '${(data['minimumLeadMinutes'] as num?)?.toInt() ?? 120}';
          _bookingHorizonDays.text =
              '${(data['bookingHorizonDays'] as num?)?.toInt() ?? 90}';
          _cancellationNoticeHours.text =
              '${(data['cancellationNoticeHours'] as num?)?.toInt() ?? 24}';
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: _slotMinutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Intervallo richieste (minuti)',
                            helperText: 'Valore iniziale: 30 minuti',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _minimumLeadMinutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Anticipo minimo (minuti)',
                            helperText: 'Valore iniziale: 120 minuti',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bookingHorizonDays,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Finestra prenotabile (giorni)',
                            helperText: 'Valore iniziale: 90 giorni',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cancellationNoticeHours,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Limite annullamento cliente (ore)',
                            helperText: 'Valore iniziale: 24 ore',
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
  return tz.TZDateTime(
    tz.getLocation(AppConfig.timezone),
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );
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
