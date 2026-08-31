import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/l10n/app_strings.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({required this.child, super.key});

  final Widget child;

  static const _paths = ['/home', '/book', '/appointments', '/profile'];
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      label: AppStrings.home,
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      label: AppStrings.book,
    ),
    NavigationDestination(
      icon: Icon(Icons.event_note_outlined),
      label: AppStrings.appointments,
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      label: AppStrings.profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _paths.indexWhere(location.startsWith).clamp(0, 3);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        appBar: AppBar(title: Text(AppConfig.appName)),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) => context.go(_paths[index]),
              destinations: _destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: destination.icon,
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(AppConfig.appName)),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: _destinations,
      ),
    );
  }
}
