import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'ritual_i18n.dart';

class RitualLocaleDefinition {
  const RitualLocaleDefinition({
    required this.code,
    required this.name,
    required this.direction,
  });

  final String code;
  final String name;
  final TextDirection direction;

  Locale get locale {
    final parts = code.split(RegExp('[-_]'));
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }
}

abstract final class RitualFlutterI18n {
  static List<RitualLocaleDefinition> _definitions = const [
    RitualLocaleDefinition(
      code: 'en',
      name: 'English',
      direction: TextDirection.ltr,
    ),
  ];
  static RitualLocaleDefinition _active = _definitions.first;

  static Locale get locale => _active.locale;
  static List<Locale> get supportedLocales =>
      _definitions.map((definition) => definition.locale).toList();
  static List<RitualLocaleDefinition> get availableLocales =>
      List.unmodifiable(_definitions);

  static Future<void> initialize({Locale? preferredLocale}) async {
    try {
      final manifest =
          jsonDecode(await rootBundle.loadString('translations/manifest.json'))
              as Map<String, dynamic>;
      final localeRows = manifest['locales'] as List<dynamic>;
      _definitions = localeRows
          .map((row) {
            final value = row as Map<String, dynamic>;
            return RitualLocaleDefinition(
              code: value['code'] as String,
              name: value['name'] as String,
              direction: value['direction'] == 'rtl'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            );
          })
          .toList(growable: false);
      final english = await _load('en');
      _active = _match(preferredLocale ?? PlatformDispatcher.instance.locale);
      final localized = _active.code == 'en'
          ? english
          : await _load(_active.code);
      final localeName = _active.locale.languageCode == 'en'
          ? null
          : _active.code.replaceAll('-', '_');
      await initializeDateFormatting(localeName);
      RitualI18n.configure(
        english: english,
        localized: localized,
        localeName: localeName,
      );
    } catch (_) {
      _definitions = const [
        RitualLocaleDefinition(
          code: 'en',
          name: 'English',
          direction: TextDirection.ltr,
        ),
      ];
      _active = _definitions.first;
      RitualI18n.configure(
        english: const {},
        localized: const {},
        localeName: null,
      );
    }
  }

  static RitualLocaleDefinition _match(Locale preferred) {
    final exact = preferred.countryCode == null
        ? preferred.languageCode
        : '${preferred.languageCode}-${preferred.countryCode}';
    return _definitions
            .where(
              (definition) =>
                  definition.code.toLowerCase() == exact.toLowerCase(),
            )
            .firstOrNull ??
        _definitions
            .where(
              (definition) =>
                  definition.locale.languageCode == preferred.languageCode,
            )
            .firstOrNull ??
        _definitions.first;
  }

  static Future<Map<String, String>> _load(String code) async {
    final document =
        jsonDecode(await rootBundle.loadString('translations/$code.json'))
            as Map<String, dynamic>;
    final strings = document['strings'] as Map<String, dynamic>;
    return strings.map((key, value) => MapEntry(key, value as String));
  }
}
