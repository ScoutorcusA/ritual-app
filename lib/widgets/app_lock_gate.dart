import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/settings_controller.dart';
import '../l10n/ritual_i18n.dart';
import '../theme/ritual_theme.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.settings,
    required this.child,
    this.now = DateTime.now,
  });

  final SettingsController settings;
  final Widget child;
  final DateTime Function() now;

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
  bool _privacyCovered = false;
  bool _authenticating = false;
  String? _message;
  late final AppLifecycleListener _lifecycleListener;
  DateTime? _backgroundedAt;
  bool _resumePending = false;
  int _trustedInterruptionDepth = 0;

  static const _reauthenticationDelay = Duration(seconds: 5);

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hideSensitiveInput();
        _authenticate();
      });
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
    _lifecycleListener.dispose();
    widget.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    _syncPlatformPrivacyShield();
    if (!widget.settings.lockEnabled) {
      _backgroundedAt = null;
      _resumePending = false;
      if (_locked || _privacyCovered) {
        setState(() {
          _locked = false;
          _privacyCovered = false;
        });
      }
    }
  }

  void _markBackgrounded() {
    if (!widget.settings.lockEnabled || _trustedInterruptionDepth > 0) return;
    _resumePending = true;
    _hideSensitiveInput();
    if (_locked || _privacyCovered) return;
    _backgroundedAt = widget.now();
    setState(() {
      _privacyCovered = true;
      _message = null;
    });
  }

  void _resume() {
    if (!_resumePending || !widget.settings.lockEnabled || !mounted) return;
    _resumePending = false;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (!_locked && _privacyCovered) {
      final elapsed = backgroundedAt == null
          ? _reauthenticationDelay
          : widget.now().difference(backgroundedAt);
      setState(() {
        _locked = elapsed.isNegative || elapsed >= _reauthenticationDelay;
        _privacyCovered = false;
      });
    }
    if (!_locked) return;
    if (widget.settings.lockMode == AppLockMode.device && !_authenticating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  Future<T> _runTrustedInterruption<T>(Future<T> Function() action) async {
    _trustedInterruptionDepth++;
    _backgroundedAt = null;
    _resumePending = false;
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

  void _hideSensitiveInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      SystemChannels.textInput
          .invokeMethod<void>('TextInput.hide')
          .catchError((Object _, StackTrace _) {}),
    );
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

  @override
  Widget build(BuildContext context) {
    final protected = _locked || _privacyCovered;
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
                    _privacyCovered
                        ? tr(
                            'Ritual hides your journal whenever the app is not active.',
                          )
                        : tr(
                            'Use your fingerprint or device screen lock to continue.',
                          ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_locked)
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _authenticate,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        _authenticating ? tr('Checking…') : tr('Unlock Ritual'),
                      ),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
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
          offstage: protected,
          child: TickerMode(
            enabled: !protected,
            child: ExcludeSemantics(
              excluding: protected,
              child: IgnorePointer(
                ignoring: protected,
                child: _TrustedInterruptionScope(
                  run: _runTrustedInterruption,
                  enabled: !protected,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (protected) Positioned.fill(child: lockScreen),
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
