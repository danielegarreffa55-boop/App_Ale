import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../../core/network/backend_api.dart';
import '../../../shared/async_value_view.dart';

class OwnerRolesSection extends ConsumerStatefulWidget {
  const OwnerRolesSection({super.key});

  @override
  ConsumerState<OwnerRolesSection> createState() => _OwnerRolesSectionState();
}

class _OwnerRolesSectionState extends ConsumerState<OwnerRolesSection> {
  static const _roles = ['client', 'manager', 'owner'];
  final _busy = <String>{};
  var _query = '';

  String _roleOf(Map<String, dynamic> account) {
    final role = account['role'];
    if (role is String && _roles.contains(role)) return role;
    if (account['isOwner'] == true) return 'owner';
    if (account['isAdmin'] == true) return 'manager';
    return 'client';
  }

  String _roleLabel(String role) => switch (role) {
    'owner' => 'Proprietario',
    'manager' => 'Gestore prenotazioni',
    _ => 'Cliente',
  };

  String _roleDescription(String role) => switch (role) {
    'owner' => 'Accesso completo alla console e alla gestione dei ruoli.',
    'manager' => 'Gestisce prenotazioni, agenda, clienti, servizi e orari.',
    _ => 'Può utilizzare soltanto le funzioni dell’app cliente.',
  };

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.message) {
        'CANNOT_CHANGE_OWN_OWNER_ROLE' =>
          'Non puoi revocare il tuo ruolo di proprietario.',
        'OWNER_REQUIRED' => 'Solo il proprietario può modificare i ruoli.',
        _ when error.code == 'not-found' => 'L’account non esiste più.',
        _ => 'Modifica del ruolo non riuscita. Riprova tra poco.',
      };
    }
    return 'Modifica del ruolo non riuscita. Riprova tra poco.';
  }

  Future<void> _changeRole(
    Map<String, dynamic> account,
    String nextRole,
  ) async {
    final uid = '${account['id'] ?? ''}';
    if (uid.isEmpty || nextRole == _roleOf(account)) return;
    final name = '${account['firstName'] ?? ''} ${account['lastName'] ?? ''}'
        .trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica ruolo'),
        content: Text(
          'Assegnare a ${name.isEmpty ? 'questo account' : name} il ruolo '
          '“${_roleLabel(nextRole)}”?\n\n${_roleDescription(nextRole)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(uid));
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .ownerSetUserRole(uid: uid, role: nextRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruolo aggiornato: ${_roleLabel(nextRole)}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(clientsProvider);
    final currentUid = ref.read(authRepositoryProvider).currentUser?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Staff e ruoli',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          'Assegna i permessi agli account già registrati.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cerca per nome o email',
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AsyncValueView<List<Map<String, dynamic>>>(
            value: accounts,
            onRetry: () => ref.invalidate(clientsProvider),
            data: (items) {
              final filtered = items.where((account) {
                final haystack = [
                  account['firstName'],
                  account['lastName'],
                  account['email'],
                ].join(' ').toLowerCase();
                return haystack.contains(_query);
              }).toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Nessun account corrispondente.'),
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = filtered[index];
                  final uid = '${account['id'] ?? ''}';
                  final role = _roleOf(account);
                  final name =
                      '${account['firstName'] ?? ''} '
                              '${account['lastName'] ?? ''}'
                          .trim();
                  final locked = uid == currentUid && role == 'owner';
                  final busy = _busy.contains(uid);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Icon(
                                  role == 'owner'
                                      ? Icons.workspace_premium_outlined
                                      : role == 'manager'
                                      ? Icons.badge_outlined
                                      : Icons.person_outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty ? 'Account' : name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text('${account['email'] ?? ''}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: ValueKey('$uid-$role'),
                            initialValue: role,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Ruolo',
                              helperText: locked
                                  ? 'Il tuo ruolo può essere cambiato da un altro proprietario.'
                                  : _roleDescription(role),
                            ),
                            items: _roles
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(_roleLabel(value)),
                                  ),
                                )
                                .toList(),
                            onChanged: busy || locked
                                ? null
                                : (value) {
                                    if (value != null) {
                                      _changeRole(account, value);
                                    }
                                  },
                          ),
                          if (busy) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(),
                          ],
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
