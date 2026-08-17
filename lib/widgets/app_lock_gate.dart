import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../theme/ritual_theme.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.settings, required this.child});

  final SettingsController settings;
  final Widget child;

  static Future<T> runTrustedInterruption<T>(
    BuildContext context,
    Future<T> Function() action,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TrustedInterruptionScope>();
    return scope == null ? action() : scope.run(action);
  }

  static bool interactionAllowed(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TrustedInterruptionScope>();
    return scope?.enabled ?? true;
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  static const _privacyChannel = MethodChannel(
    'com.nishkamkhanna.ritual/privacy',
  );

  bool _locked = false;
  bool _authenticating = false;
  String _pin = '';
  String? _message;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;
  Timer? _timer;
  Timer? _backgroundLockTimer;
  late final AppLifecycleListener _lifecycleListener;
  bool _lockOnResume = false;
  int _trustedInterruptionDepth = 0;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onInactive: _markBackgrounded,
      onHide: _markBackgrounded,
      onPause: _markBackgrounded,
      onResume: _resume,
    );
    widget.settings.addListener(_settingsChanged);
    _locked = widget.settings.lockEnabled;
    _syncPlatformPrivacyShield();
    if (_locked && widget.settings.lockMode == AppLockMode.device) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.removeListener(_settingsChanged);
      widget.settings.addListener(_settingsChanged);
      _settingsChanged();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _backgroundLockTimer?.cancel();
    _lifecycleListener.dispose();
    widget.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    _syncPlatformPrivacyShield();
    if (!widget.settings.lockEnabled) {
      _backgroundLockTimer?.cancel();
      _backgroundLockTimer = null;
      _lockOnResume = false;
      if (_locked) setState(() => _locked = false);
    }
  }

  void _markBackgrounded() {
    if (!widget.settings.lockEnabled || _trustedInterruptionDepth > 0) return;
    _lockOnResume = true;
    if (_locked || _backgroundLockTimer != null) return;
    _backgroundLockTimer = Timer(const Duration(seconds: 5), () {
      _backgroundLockTimer = null;
      if (!mounted ||
          !widget.settings.lockEnabled ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        return;
      }
      setState(() {
        _locked = true;
        _pin = '';
        _message = null;
      });
    });
  }

  void _resume() {
    if (!_lockOnResume || !widget.settings.lockEnabled || !mounted) return;
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = null;
    _lockOnResume = false;
    if (!_locked) return;
    if (widget.settings.lockMode == AppLockMode.device && !_authenticating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  Future<T> _runTrustedInterruption<T>(Future<T> Function() action) async {
    _trustedInterruptionDepth++;
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = null;
    _lockOnResume = false;
    try {
      return await action();
    } finally {
      _trustedInterruptionDepth--;
      if (_trustedInterruptionDepth == 0 &&
          mounted &&
          widget.settings.lockEnabled &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _markBackgrounded();
      }
    }
  }

  void _syncPlatformPrivacyShield() {
    unawaited(
      _privacyChannel
          .invokeMethod<void>('setAppLockEnabled', widget.settings.lockEnabled)
          .catchError((Object _, StackTrace _) {}),
    );
  }

  Future<void> _authenticate() async {
    if (_authenticating || !_locked) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final unlocked = await widget.settings.authenticateDevice();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !unlocked;
      if (!unlocked) _message = tr('Ritual is still locked.');
    });
  }

  Future<void> _enterDigit(String digit) async {
    if (_blockedUntil?.isAfter(DateTime.now()) ?? false) return;
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
    if (_pin.length != 4) return;
    final correct = await widget.settings.verifyPin(_pin);
    if (!mounted) return;
    if (correct) {
      setState(() {
        _locked = false;
        _pin = '';
        _failedAttempts = 0;
      });
      return;
    }
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!(_blockedUntil?.isAfter(DateTime.now()) ?? false)) {
          _timer?.cancel();
          setState(() {
            _failedAttempts = 0;
            _blockedUntil = null;
            _message = null;
          });
        } else {
          setState(() {});
        }
      });
    }
    setState(() {
      _pin = '';
      _message = _blockedUntil == null
          ? tr('That PIN was not correct.')
          : tr('Too many attempts. Try again in 30 seconds.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinMode = widget.settings.lockMode == AppLockMode.pin;
    final remaining = _blockedUntil?.difference(DateTime.now()).inSeconds;
    final lockScreen = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: RitualColors.sage.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 38,
                      color: RitualColors.sage,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('Your journal is private'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pinMode
                        ? tr('Enter your four-digit Ritual PIN.')
                        : tr(
                            'Use your fingerprint or device screen lock to continue.',
                          ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (pinMode) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _pin.length
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var row = 0; row < 3; row++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var column = 1; column <= 3; column++)
                            _PinKey(
                              label: '${row * 3 + column}',
                              onTap: () => _enterDigit('${row * 3 + column}'),
                            ),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 64),
                        _PinKey(label: '0', onTap: () => _enterDigit('0')),
                        SizedBox(
                          width: 72,
                          height: 64,
                          child: IconButton(
                            tooltip: tr('Delete digit'),
                            onPressed: _pin.isEmpty
                                ? null
                                : () => setState(
                                    () => _pin = _pin.substring(
                                      0,
                                      _pin.length - 1,
                                    ),
                                  ),
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _authenticate,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        _authenticating ? tr('Checking…') : tr('Unlock Ritual'),
                      ),
                    ),
                  if (_message != null || remaining != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      remaining != null && remaining > 0
                          ? tr(
                              'Try again in {count} seconds.',
                              values: {'count': remaining},
                            )
                          : _message ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: _locked,
          child: TickerMode(
            enabled: !_locked,
            child: ExcludeSemantics(
              excluding: _locked,
              child: IgnorePointer(
                ignoring: _locked,
                child: _TrustedInterruptionScope(
                  run: _runTrustedInterruption,
                  enabled: !_locked,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (_locked) Positioned.fill(child: lockScreen),
      ],
    );
  }
}

class _TrustedInterruptionScope extends InheritedWidget {
  const _TrustedInterruptionScope({
    required this.run,
    required this.enabled,
    required super.child,
  });

  final Future<T> Function<T>(Future<T> Function() action) run;
  final bool enabled;

  @override
  bool updateShouldNotify(_TrustedInterruptionScope oldWidget) =>
      enabled != oldWidget.enabled;
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 64,
    child: TextButton(
      onPressed: onTap,
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}
