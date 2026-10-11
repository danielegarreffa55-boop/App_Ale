import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';

class OwnerAnnouncementSection extends ConsumerStatefulWidget {
  const OwnerAnnouncementSection({super.key});

  @override
  ConsumerState<OwnerAnnouncementSection> createState() =>
      _OwnerAnnouncementSectionState();
}

class _OwnerAnnouncementSectionState
    extends ConsumerState<OwnerAnnouncementSection> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  var _active = true;
  var _loaded = false;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .saveAnnouncement(
            title: _title.text,
            message: _message.text,
            active: _active,
          );
      ref.invalidate(studioConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avviso clienti pubblicato.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(studioConfigProvider).value;
    if (config == null) return const Center(child: CircularProgressIndicator());
    if (!_loaded) {
      final raw = config['announcement'];
      if (raw is Map) {
        final announcement = Map<String, dynamic>.from(raw);
        _title.text = announcement['title'] as String? ?? '';
        _message.text = announcement['message'] as String? ?? '';
        _active = announcement['active'] as bool? ?? true;
      }
      _loaded = true;
    }
    return ListView(
      children: [
        Text(
          'Avviso clienti',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 4),
        const Text(
          'Crea il popup mostrato ai clienti quando aprono l’app: promozioni, ferie o comunicazioni importanti.',
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
                    TextField(
                      controller: _title,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Titolo',
                        hintText: 'Chiusura estiva',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _message,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        labelText: 'Messaggio',
                        hintText: 'Lo studio resterà chiuso dal…',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                      title: const Text('Mostra il popup ai clienti'),
                      subtitle: Text(
                        _active ? 'Avviso attivo' : 'Avviso disattivato',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text(_saving ? 'Salvataggio…' : 'Salva avviso'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
