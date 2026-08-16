import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/l10n/ritual_i18n.dart';

void main() {
  tearDown(() {
    RitualI18n.configure(
      english: const {},
      localized: const {},
      localeName: null,
    );
  });

  test(
    'uses localized values, placeholders, plurals, and English fallback',
    () {
      RitualI18n.configure(
        english: const {
          'Journal': 'Journal',
          'Hello, {name}': 'Hello, {name}',
          '{count} entry': '{count} entry',
          '{count} entries': '{count} entries',
          'Fallback': 'Fallback',
        },
        localized: const {
          'Journal': 'Diario',
          'Hello, {name}': 'Hola, {name}',
          '{count} entry': '{count} entrada',
          '{count} entries': '{count} entradas',
        },
        localeName: 'es',
      );

      expect(tr('Journal'), 'Diario');
      expect(tr('Hello, {name}', values: {'name': 'Ritual'}), 'Hola, Ritual');
      expect(
        trPlural(1, one: '{count} entry', other: '{count} entries'),
        '1 entrada',
      );
      expect(
        trPlural(3, one: '{count} entry', other: '{count} entries'),
        '3 entradas',
      );
      expect(tr('Fallback'), 'Fallback');
    },
  );
}
