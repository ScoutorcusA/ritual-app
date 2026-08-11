import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockMode { off, device, pin }

class SettingsController extends ChangeNotifier {
  SettingsController({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuthentication,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _themeKey = 'theme_mode';
  static const _lockModeKey = 'app_lock_mode';
  static const _pinSaltKey = 'ritual_pin_salt';
  static const _pinHashKey = 'ritual_pin_hash';
  static const _hashRounds = 50000;

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuthentication;

  ThemeMode _themeMode = ThemeMode.system;
  AppLockMode _lockMode = AppLockMode.off;

  ThemeMode get themeMode => _themeMode;
  AppLockMode get lockMode => _lockMode;
  bool get lockEnabled => _lockMode != AppLockMode.off;

  Future<void> initialize() async {
    final storedTheme = await _preferences.getString(_themeKey);
    _themeMode =
        ThemeMode.values
            .where((mode) => mode.name == storedTheme)
            .firstOrNull ??
        ThemeMode.system;
    final storedLock = await _preferences.getString(_lockModeKey);
    _lockMode =
        AppLockMode.values
            .where((mode) => mode.name == storedLock)
            .firstOrNull ??
        AppLockMode.off;
    if (_lockMode == AppLockMode.pin) {
      final hash = await _secureStorage.read(key: _pinHashKey);
      final salt = await _secureStorage.read(key: _pinSaltKey);
      if (hash == null || salt == null) {
        _lockMode = AppLockMode.off;
        await _preferences.setString(_lockModeKey, _lockMode.name);
      }
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    await _preferences.setString(_themeKey, value.name);
  }

  Future<bool> deviceAuthenticationSupported() =>
      _localAuthentication.isDeviceSupported();

  Future<bool> authenticateDevice() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Unlock your private Ritual journal',
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> enableDeviceLock() async {
    if (!await deviceAuthenticationSupported()) return false;
    if (!await authenticateDevice()) return false;
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
    _lockMode = AppLockMode.device;
    notifyListeners();
    await _preferences.setString(_lockModeKey, _lockMode.name);
    return true;
  }

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain exactly four digits.');
    }
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _hashPin(pin, salt);
    await _secureStorage.write(key: _pinSaltKey, value: salt);
    await _secureStorage.write(key: _pinHashKey, value: hash);
    _lockMode = AppLockMode.pin;
    notifyListeners();
    await _preferences.setString(_lockModeKey, _lockMode.name);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _secureStorage.read(key: _pinSaltKey);
    final expected = await _secureStorage.read(key: _pinHashKey);
    if (salt == null || expected == null) return false;
    final actual = _hashPin(pin, salt);
    var difference = actual.length ^ expected.length;
    final length = min(actual.length, expected.length);
    for (var index = 0; index < length; index++) {
      difference |= actual.codeUnitAt(index) ^ expected.codeUnitAt(index);
    }
    return difference == 0;
  }

  Future<void> disableLock() async {
    _lockMode = AppLockMode.off;
    notifyListeners();
    await _preferences.setString(_lockModeKey, _lockMode.name);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
  }

  String _hashPin(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin')).bytes;
    for (var round = 1; round < _hashRounds; round++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64UrlEncode(digest);
  }
}
