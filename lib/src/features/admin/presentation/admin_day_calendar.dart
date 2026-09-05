import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_x.dart';
import '../../appointments/domain/appointment_models.dart';

class AdminDayCalendar extends StatefulWidget {
  const AdminDayCalendar({
    required this.day,
    required this.appointments,
    required this.blocks,
    required this.startHour,
    required this.endHour,
    required this.onEmptySlotTap,
    required this.onAppointmentTap,
    required this.onBlockTap,
    this.openingStartMinute,
    this.openingEndMinute,
    super.key,
  });

  final DateTime day;
  final List<Appointment> appointments;
  final List<AgendaBlock> blocks;
  final int startHour;
  final int endHour;
  final int? openingStartMinute;
  final int? openingEndMinute;
  final ValueChanged<DateTime> onEmptySlotTap;
  final ValueChanged<Appointment> onAppointmentTap;
  final ValueChanged<AgendaBlock> onBlockTap;

  @override
  State<AdminDayCalendar> createState() => _AdminDayCalendarState();
}

class _AdminDayCalendarState extends State<AdminDayCalendar> {
  static const _hourHeight = 72.0;
  static const _slotMinutes = 30;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToRelevantTime();
  }

  @override
  void didUpdateWidget(covariant AdminDayCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.day, widget.day) ||
        (oldWidget.appointments.isEmpty && widget.appointments.isNotEmpty) ||
        (oldWidget.blocks.isEmpty && widget.blocks.isNotEmpty)) {
      _scrollToRelevantTime();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRelevantTime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final now = DateTime.now().inStudioTimezone;
      int targetMinute;
      if (_sameDay(widget.day, now)) {
        targetMinute = now.hour * 60 + now.minute;
      } else {
        final starts = <int>[
          ...widget.appointments.map((item) {
            final local = item.effectiveStartAt.inStudioTimezone;
            return local.hour * 60 + local.minute;
          }),
          ...widget.blocks.map((item) {
            final local = item.startAt.inStudioTimezone;
            return local.hour * 60 + local.minute;
          }),
        ];
        targetMinute = starts.isEmpty
            ? widget.openingStartMinute ?? widget.startHour * 60
            : starts.reduce(math.min);
      }
      final offset =
          ((targetMinute - widget.startHour * 60) / 60 * _hourHeight) - 96;
      _scrollController.jumpTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final durationHours = widget.endHour - widget.startHour;
    final totalHeight = durationHours * _hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutterWidth = constraints.maxWidth < 520 ? 54.0 : 72.0;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    for (var index = 0; index < durationHours; index++) ...[
                      _TimeLine(
                        top: index * _hourHeight,
                        gutterWidth: gutterWidth,
                        label:
                            '${(widget.startHour + index).toString().padLeft(2, '0')}:00',
                        strong: true,
                      ),
                      _TimeLine(
                        top: index * _hourHeight + _hourHeight / 2,
                        gutterWidth: gutterWidth,
                      ),
                    ],
                    _TimeLine(
                      top: totalHeight - 1,
                      gutterWidth: gutterWidth,
                      strong: true,
                    ),
                    ..._closedAreas(
                      context,
                      gutterWidth: gutterWidth,
                      totalHeight: totalHeight,
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: gutterWidth,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) =>
                            _handleSlotTap(details.localPosition.dy),
                      ),
                    ),
                    for (final block in widget.blocks)
                      ?_blockTile(
                        context,
                        block,
                        gutterWidth: gutterWidth,
                        totalHeight: totalHeight,
                      ),
                    for (final appointment in widget.appointments)
                      ?_appointmentTile(
                        context,
                        appointment,
                        gutterWidth: gutterWidth,
                        totalHeight: totalHeight,
                      ),
                    ?_currentTimeLine(
                      gutterWidth: gutterWidth,
                      totalHeight: totalHeight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _closedAreas(
    BuildContext context, {
    required double gutterWidth,
    required double totalHeight,
  }) {
    final start = widget.startHour * 60;
    final end = widget.endHour * 60;
    final openingStart = widget.openingStartMinute;
    final openingEnd = widget.openingEndMinute;
    if (openingStart == null || openingEnd == null) {
      return [
        _ClosedArea(
          top: 0,
          height: totalHeight,
          left: gutterWidth,
          label: 'Studio chiuso',
        ),
      ];
    }
    final beforeHeight = _minuteToOffset(openingStart.clamp(start, end));
    final afterTop = _minuteToOffset(openingEnd.clamp(start, end));
    return [
      if (beforeHeight > 0)
        _ClosedArea(
          top: 0,
          height: beforeHeight,
          left: gutterWidth,
          label: 'Chiuso',
        ),
      if (afterTop < totalHeight)
        _ClosedArea(
          top: afterTop,
          height: totalHeight - afterTop,
          left: gutterWidth,
          label: 'Chiuso',
        ),
    ];
  }

  void _handleSlotTap(double offset) {
    final rawMinute = widget.startHour * 60 + offset / _hourHeight * 60;
    final minute = (rawMinute / _slotMinutes).floor() * _slotMinutes;
    final openingStart = widget.openingStartMinute;
    final openingEnd = widget.openingEndMinute;
    if (openingStart == null ||
        openingEnd == null ||
        minute < openingStart ||
        minute >= openingEnd) {
      return;
    }
    final hour = minute ~/ 60;
    final minuteOfHour = minute % 60;
    final location = tz.getLocation(AppConfig.timezone);
    widget.onEmptySlotTap(
      tz.TZDateTime(
        location,
        widget.day.year,
        widget.day.month,
        widget.day.day,
        hour,
        minuteOfHour,
      ),
    );
  }

  Widget? _appointmentTile(
    BuildContext context,
    Appointment appointment, {
    required double gutterWidth,
    required double totalHeight,
  }) {
    final start = appointment.effectiveStartAt.inStudioTimezone;
    final end = appointment.effectiveEndAt.inStudioTimezone;
    if (!_overlapsSelectedDay(start, end)) return null;
    final position = _eventPosition(start, end, totalHeight);
    if (position == null) return null;
    final completed = appointment.status == AppointmentStatus.completed;
    final theme = Theme.of(context);
    return Positioned(
      top: position.$1,
      left: gutterWidth + 7,
      right: 8,
      height: position.$2,
      child: Semantics(
        button: true,
        label:
            '${appointment.clientName ?? 'Cliente'}, ${appointment.serviceName}, ${start.italianTime}',
        child: Material(
          color: completed
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: completed
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary.withValues(alpha: 0.78),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onAppointmentTap(appointment),
            child: Row(
              children: [
                Container(
                  width: 4,
                  color: completed
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.clientName ?? 'Cliente',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: completed
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                        if (position.$2 >= 31)
                          Text(
                            '${start.italianTime}–${end.italianTime} · ${appointment.serviceName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  (completed
                                          ? theme.colorScheme.onSurface
                                          : theme
                                                .colorScheme
                                                .onPrimaryContainer)
                                      .withValues(alpha: 0.75),
                              fontSize: 9.5,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.more_horiz_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _blockTile(
    BuildContext context,
    AgendaBlock block, {
    required double gutterWidth,
    required double totalHeight,
  }) {
    final start = block.startAt.inStudioTimezone;
    final end = block.endAt.inStudioTimezone;
    if (!_overlapsSelectedDay(start, end)) return null;
    final position = _eventPosition(start, end, totalHeight);
    if (position == null) return null;
    final theme = Theme.of(context);
    return Positioned(
      top: position.$1,
      left: gutterWidth + 7,
      right: 8,
      height: position.$2,
      child: Semantics(
        button: true,
        label: 'Fascia bloccata, ${block.reason}',
        child: Material(
          color: AppTheme.black.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.75),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onBlockTap(block),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 17,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${start.italianTime}–${end.italianTime} · ${block.reason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _currentTimeLine({
    required double gutterWidth,
    required double totalHeight,
  }) {
    final now = DateTime.now().inStudioTimezone;
    if (!_sameDay(widget.day, now)) return null;
    final minute = now.hour * 60 + now.minute;
    final top = _minuteToOffset(minute);
    if (top < 0 || top > totalHeight) return null;
    return Positioned(
      top: top,
      left: gutterWidth - 5,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.gold,
                shape: BoxShape.circle,
              ),
            ),
            const Expanded(child: Divider(color: AppTheme.gold, height: 1)),
          ],
        ),
      ),
    );
  }

  (double, double)? _eventPosition(
    DateTime eventStart,
    DateTime eventEnd,
    double totalHeight,
  ) {
    final startOfView = widget.startHour * 60;
    final endOfView = widget.endHour * 60;
    final rawStart = _sameDay(widget.day, eventStart)
        ? eventStart.hour * 60 + eventStart.minute
        : startOfView;
    final rawEnd = _sameDay(widget.day, eventEnd)
        ? eventEnd.hour * 60 + eventEnd.minute
        : endOfView;
    final visibleStart = rawStart.clamp(startOfView, endOfView);
    final visibleEnd = rawEnd.clamp(startOfView, endOfView);
    if (visibleEnd <= visibleStart) return null;
    final top = _minuteToOffset(visibleStart);
    final naturalHeight = (visibleEnd - visibleStart) / 60 * _hourHeight;
    final height = math
        .max(32.0, naturalHeight - 3)
        .clamp(0, totalHeight - top);
    return (top + 1.5, height.toDouble());
  }

  double _minuteToOffset(num minute) =>
      (minute - widget.startHour * 60) / 60 * _hourHeight;

  bool _overlapsSelectedDay(DateTime start, DateTime end) {
    final location = tz.getLocation(AppConfig.timezone);
    final dayStart = tz.TZDateTime(
      location,
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final dayEnd = tz.TZDateTime(
      location,
      widget.day.year,
      widget.day.month,
      widget.day.day + 1,
    );
    return end.isAfter(dayStart) && start.isBefore(dayEnd);
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({
    required this.top,
    required this.gutterWidth,
    this.label,
    this.strong = false,
  });

  final double top;
  final double gutterWidth;
  final String? label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: gutterWidth - 8,
            child: Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                label ?? '',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: strong ? 1 : 0.5,
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: strong ? 0.7 : 0.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedArea extends StatelessWidget {
  const _ClosedArea({
    required this.top,
    required this.height,
    required this.left,
    required this.label,
  });

  final double top;
  final double height;
  final double left;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: 0,
      height: height,
      child: ColoredBox(
        color: AppTheme.black.withValues(alpha: 0.34),
        child: height >= 38
            ? Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.42),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
