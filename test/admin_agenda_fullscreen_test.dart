import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_booking/src/core/theme/app_theme.dart';
import 'package:salon_booking/src/features/admin/presentation/admin_calendar_views.dart';
import 'package:salon_booking/src/features/admin/presentation/admin_page.dart';
import 'package:salon_booking/src/providers.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    await initializeDateFormatting('it_IT');
  });

  testWidgets('agenda entra ed esce da schermo intero mantenendo la vista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith((ref) async => true),
          isOwnerProvider.overrideWith((ref) async => false),
          adminAppointmentsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          adminAgendaProvider.overrideWith(
            (ref, range) => Stream.value(const []),
          ),
          adminBlocksProvider.overrideWith((ref) => Stream.value(const [])),
          studioConfigProvider.overrideWith(
            (ref) => Stream.value(const <String, dynamic>{}),
          ),
          clientsProvider.overrideWith((ref) => Stream.value(const [])),
          adminServicesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(theme: AppTheme.editorial, home: const AdminPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apri agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settimana'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<AgendaViewMode>>(
            find.byType(SegmentedButton<AgendaViewMode>),
          )
          .selected,
      {AgendaViewMode.week},
    );

    await tester.tap(find.byKey(const Key('agendaEnterFullScreen')));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('agendaExitFullScreen')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<AgendaViewMode>>(
            find.byType(SegmentedButton<AgendaViewMode>),
          )
          .selected,
      {AgendaViewMode.week},
    );

    await tester.tap(find.byKey(const Key('agendaExitFullScreen')));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('agendaEnterFullScreen')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<AgendaViewMode>>(
            find.byType(SegmentedButton<AgendaViewMode>),
          )
          .selected,
      {AgendaViewMode.week},
    );
    expect(tester.takeException(), isNull);
  });
}
