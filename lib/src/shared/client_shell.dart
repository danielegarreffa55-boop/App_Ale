import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../providers.dart';
import 'brand_logo.dart';

class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  var _startupDialogsHandled = false;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupDialogs());
  }

  Future<void> _showStartupDialogs() async {
    if (_startupDialogsHandled || !mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    _startupDialogsHandled = true;

    final notifications = ref.read(notificationServiceProvider);
    final alreadyAsked = await notifications.firstPromptWasShown(user.uid);
    final enabled = await notifications.permissionEnabled();
    if (!alreadyAsked && enabled != true && mounted) {
      final activate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined),
          title: const Text('Vuoi attivare le notifiche?'),
          content: const Text(
            'Riceverai conferme, controproposte e promemoria degli appuntamenti. '
            'Potrai abilitarle o disabilitarle in qualsiasi momento dalla sezione Profilo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non ora'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Attiva'),
            ),
          ],
        ),
      );
      await notifications.markFirstPromptShown(user.uid);
      if (activate == true) {
        await notifications.requestAndRegister(userId: user.uid);
      }
    } else if (!alreadyAsked) {
      await notifications.markFirstPromptShown(user.uid);
    }

    if (!mounted) return;
    try {
      final config = await ref
          .read(appointmentRepositoryProvider)
          .fetchStudioConfig();
      final raw = config['announcement'];
      if (raw is! Map) return;
      final announcement = Map<String, dynamic>.from(raw);
      final id = (announcement['id'] as String? ?? '').trim();
      final title = (announcement['title'] as String? ?? '').trim();
      final message = (announcement['message'] as String? ?? '').trim();
      if (announcement['active'] != true ||
          id.isEmpty ||
          title.isEmpty ||
          message.isEmpty) {
        return;
      }
      final preferences = ref.read(announcementPreferenceServiceProvider);
      final dismissed = await preferences.wasDismissed(
        userId: user.uid,
        announcementId: id,
      );
      if (dismissed) return;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.campaign_outlined),
          title: Text(title, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  await preferences.dismiss(
                    userId: user.uid,
                    announcementId: id,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  'Non mostrare più questo avviso',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Il resto dell'app rimane utilizzabile se l'avviso non è disponibile.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.value != null && !_startupDialogsHandled) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showStartupDialogs(),
        );
      }
    });
    final location = GoRouterState.of(context).uri.path;
    final selected = _paths.indexWhere(location.startsWith).clamp(0, 3);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        appBar: AppBar(title: const BrandWordmark()),
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
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const BrandWordmark()),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: _destinations,
      ),
    );
  }
}
