import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_x.dart';
import '../../appointments/domain/appointment_models.dart';

enum AgendaViewMode { day, week, month }

class AdminWeekCalendar extends StatelessWidget {
  const AdminWeekCalendar({
    required this.selectedDay,
    required this.appointments,
    required this.blocks,
    required this.startHour,
    required this.endHour,
    required this.onEmptySlotTap,
    required this.onAppointmentTap,
    required this.onBlockTap,
    required this.onDayTap,
    super.key,
  });

  final DateTime selectedDay;
  final List<Appointment> appointments;
  final List<AgendaBlock> blocks;
  final int startHour;
  final int endHour;
  final ValueChanged<DateTime> onEmptySlotTap;
  final ValueChanged<Appointment> onAppointmentTap;
  final ValueChanged<AgendaBlock> onBlockTap;
  final ValueChanged<DateTime> onDayTap;

  static const _hourHeight = 62.0;
  static const _gutterWidth = 48.0;
  static const _dayWidth = 118.0;

  DateTime get _weekStart => selectedDay.subtract(
    Duration(days: selectedDay.weekday - DateTime.monday),
  );

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final bodyHeight = (endHour - startHour) * _hourHeight;
    final calendarWidth = _gutterWidth + days.length * _dayWidth;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, calendarWidth),
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      const SizedBox(width: _gutterWidth),
                      for (final day in days)
                        Expanded(
                          child: _WeekDayHeader(
                            day: day,
                            selected: _sameDay(day, selectedDay),
                            onTap: () => onDayTap(day),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: bodyHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _gutterWidth,
                            child: Stack(
                              children: [
                                for (
                                  var hour = startHour;
                                  hour < endHour;
                                  hour++
                                )
                                  Positioned(
                                    top: (hour - startHour) * _hourHeight - 7,
                                    right: 7,
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:00',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppTheme.subtle),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final day in days)
                            Expanded(
                              child: _WeekDayColumn(
                                day: day,
                                appointments: appointments,
                                blocks: blocks,
                                startHour: startHour,
                                endHour: endHour,
                                hourHeight: _hourHeight,
                                onEmptySlotTap: onEmptySlotTap,
                                onAppointmentTap: onAppointmentTap,
                                onBlockTap: onBlockTap,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(day, DateTime.now().inStudioTimezone);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.08) : null,
          border: const Border(
            left: BorderSide(color: AppTheme.line, width: .5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE', 'it_IT').format(day).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppTheme.muted, letterSpacing: .8),
            ),
            const SizedBox(height: 4),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: today
                  ? const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: today ? AppTheme.canvas : AppTheme.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.appointments,
    required this.blocks,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.onEmptySlotTap,
    required this.onAppointmentTap,
    required this.onBlockTap,
  });
  final DateTime day;
  final List<Appointment> appointments;
  final List<AgendaBlock> blocks;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final ValueChanged<DateTime> onEmptySlotTap;
  final ValueChanged<Appointment> onAppointmentTap;
  final ValueChanged<AgendaBlock> onBlockTap;

  @override
  Widget build(BuildContext context) {
    final dayAppointments = appointments.where(
      (item) => _sameDay(item.effectiveStartAt.inStudioTimezone, day),
    );
    final dayBlocks = blocks.where(
      (item) => _sameDay(item.startAt.inStudioTimezone, day),
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final raw = startHour * 60 + details.localPosition.dy / hourHeight * 60;
        final minute = (raw / 30).floor() * 30;
        onEmptySlotTap(
          tz.TZDateTime(
            tz.getLocation(AppConfig.timezone),
            day.year,
            day.month,
            day.day,
            minute ~/ 60,
            minute % 60,
          ),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppTheme.line, width: .5),
                ),
              ),
            ),
          ),
          for (var hour = startHour; hour <= endHour; hour++)
            Positioned(
              top: (hour - startHour) * hourHeight,
              left: 0,
              right: 0,
              child: const Divider(height: 1, color: AppTheme.line),
            ),
          for (var hour = startHour; hour < endHour; hour++)
            Positioned(
              top: (hour - startHour) * hourHeight + hourHeight / 2,
              left: 0,
              right: 0,
              child: Divider(
                height: 1,
                color: AppTheme.line.withValues(alpha: .35),
              ),
            ),
          for (final block in dayBlocks) _weekBlock(context, block),
          for (final appointment in dayAppointments)
            _weekAppointment(context, appointment),
        ],
      ),
    );
  }

  Widget _weekAppointment(BuildContext context, Appointment item) {
    final start = item.effectiveStartAt.inStudioTimezone;
    final end = item.effectiveEndAt.inStudioTimezone;
    final top =
        ((start.hour * 60 + start.minute) - startHour * 60) / 60 * hourHeight;
    final height = math.max(
      24.0,
      end.difference(start).inMinutes / 60 * hourHeight - 2,
    );
    return Positioned(
      top: top + 1,
      left: 3,
      right: 3,
      height: height,
      child: Material(
        color: item.status == AppointmentStatus.pendingAdmin
            ? Colors.orange.withValues(alpha: .18)
            : AppTheme.accent.withValues(alpha: .16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: item.status == AppointmentStatus.pendingAdmin
                ? Colors.orange
                : AppTheme.accent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onAppointmentTap(item),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              '${start.italianTime}  ${item.clientName ?? 'Cliente'}\n${item.serviceName}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontSize: 8.5, height: 1.15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekBlock(BuildContext context, AgendaBlock block) {
    final start = block.startAt.inStudioTimezone;
    final end = block.endAt.inStudioTimezone;
    final top =
        ((start.hour * 60 + start.minute) - startHour * 60) / 60 * hourHeight;
    final height = math.max(
      22.0,
      end.difference(start).inMinutes / 60 * hourHeight - 2,
    );
    return Positioned(
      top: top + 1,
      left: 3,
      right: 3,
      height: height,
      child: Material(
        color: AppTheme.panelStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppTheme.line),
        ),
        child: InkWell(
          onTap: () => onBlockTap(block),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              block.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}

class AdminMonthCalendar extends StatelessWidget {
  const AdminMonthCalendar({
    required this.selectedDay,
    required this.appointments,
    required this.onDayTap,
    required this.onAppointmentTap,
    super.key,
  });
  final DateTime selectedDay;
  final List<Appointment> appointments;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<Appointment> onAppointmentTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDay.year, selectedDay.month, 1);
    final gridStart = first.subtract(
      Duration(days: first.weekday - DateTime.monday),
    );
    final days = List.generate(
      42,
      (index) => gridStart.add(Duration(days: index)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final label in const [
                  'LUN',
                  'MAR',
                  'MER',
                  'GIO',
                  'VEN',
                  'SAB',
                  'DOM',
                ])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.muted,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .95,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final items =
                    appointments
                        .where(
                          (item) => _sameDay(
                            item.effectiveStartAt.inStudioTimezone,
                            day,
                          ),
                        )
                        .toList()
                      ..sort(
                        (a, b) =>
                            a.effectiveStartAt.compareTo(b.effectiveStartAt),
                      );
                final outside = day.month != selectedDay.month;
                final today = _sameDay(day, DateTime.now().inStudioTimezone);
                return InkWell(
                  onTap: () => onDayTap(day),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: AppTheme.line, width: .5),
                        bottom: BorderSide(color: AppTheme.line, width: .5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: today
                              ? const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            '${day.day}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: outside
                                      ? AppTheme.subtle
                                      : today
                                      ? AppTheme.canvas
                                      : AppTheme.ink,
                                ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        for (final item in items.take(3))
                          InkWell(
                            onTap: () => onAppointmentTap(item),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${item.effectiveStartAt.italianTime} ${item.clientName ?? item.serviceName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 7.5),
                              ),
                            ),
                          ),
                        if (items.length > 3)
                          Text(
                            '+${items.length - 3}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppTheme.muted, fontSize: 7),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
