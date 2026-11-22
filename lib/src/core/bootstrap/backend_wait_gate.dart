import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/brand_logo.dart';

typedef ReadinessAttempt = Future<bool> Function();

class BackendWaitGate extends StatefulWidget {
  const BackendWaitGate({
    required this.child,
    required this.initialAttempt,
    required this.retry,
    this.onReady,
    this.onAttemptTimeout,
    this.gracePeriod = const Duration(seconds: 1),
    this.attemptTimeout = const Duration(seconds: 25),
    this.phrasePeriod = const Duration(seconds: 2),
    super.key,
  });

  final Widget child;
  final Future<bool>? initialAttempt;
  final ReadinessAttempt retry;
  final VoidCallback? onReady;
  final VoidCallback? onAttemptTimeout;
  final Duration gracePeriod;
  final Duration attemptTimeout;
  final Duration phrasePeriod;

  @override
  State<BackendWaitGate> createState() => _BackendWaitGateState();
}

enum _GateState { waitingQuietly, waitingVisible, failed, ready }

class _BackendWaitGateState extends State<BackendWaitGate> {
  static const _phrases = [
    'Sto affilando le forbici…',
    'Preparo la schiuma da barba…',
    'Sistemo la poltrona…',
  ];

  _GateState _state = _GateState.waitingQuietly;
  Timer? _graceTimer;
  Timer? _phraseTimer;
  Timer? _attemptTimer;
  int _phraseIndex = 0;
  int _attemptId = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAttempt;
    if (initial == null) {
      _state = _GateState.ready;
      widget.onReady?.call();
    } else {
      _watch(initial);
    }
  }

  void _watch(Future<bool> attempt) {
    final id = ++_attemptId;
    _graceTimer?.cancel();
    _phraseTimer?.cancel();
    _attemptTimer?.cancel();
    _phraseIndex = 0;
    _state = _GateState.waitingQuietly;
    _graceTimer = Timer(widget.gracePeriod, () {
      if (!mounted || id != _attemptId) return;
      setState(() => _state = _GateState.waitingVisible);
      _phraseTimer = Timer.periodic(widget.phrasePeriod, (_) {
        if (!mounted || id != _attemptId) return;
        setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
      });
    });

    _attemptTimer = Timer(widget.attemptTimeout, () {
      if (!mounted || id != _attemptId) return;
      widget.onAttemptTimeout?.call();
      _finish(id, ready: false);
      _attemptId++;
    });

    attempt.then(
      (ready) => _finish(id, ready: ready),
      onError: (_) => _finish(id, ready: false),
    );
  }

  void _finish(int id, {required bool ready}) {
    if (!mounted || id != _attemptId) return;
    _graceTimer?.cancel();
    _phraseTimer?.cancel();
    _attemptTimer?.cancel();
    if (ready) widget.onReady?.call();
    setState(() => _state = ready ? _GateState.ready : _GateState.failed);
  }

  void _retry() {
    if (_state != _GateState.failed) return;
    _watch(widget.retry());
  }

  @override
  void dispose() {
    _attemptId++;
    if (_state != _GateState.ready) widget.onAttemptTimeout?.call();
    _graceTimer?.cancel();
    _phraseTimer?.cancel();
    _attemptTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_state != _GateState.ready)
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0xFF101216)),
          ),
        if (_state == _GateState.waitingVisible || _state == _GateState.failed)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const BrandWordmark(),
                              const SizedBox(height: 32),
                              if (_state == _GateState.waitingVisible) ...[
                                const CircularProgressIndicator(
                                  key: Key('backendWaitProgress'),
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    _phrases[_phraseIndex],
                                    key: ValueKey(_phraseIndex),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Il salone tarda ad aprire',
                                  key: const Key('backendWaitError'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  key: const Key('backendWaitRetry'),
                                  onPressed: _retry,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Riprova'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
