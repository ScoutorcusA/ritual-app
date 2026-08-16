abstract final class RitualI18n {
  static Map<String, String> _english = const {};
  static Map<String, String> _localized = const {};
  static String? _localeName;

  static String? get localeName => _localeName;

  static void configure({
    required Map<String, String> english,
    required Map<String, String> localized,
    required String? localeName,
  }) {
    _english = english;
    _localized = localized;
    _localeName = localeName;
  }

  static String translate(
    String source, {
    Map<String, Object?> values = const {},
  }) {
    var result = _localized[source] ?? _english[source] ?? source;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  static String plural(
    int count, {
    required String one,
    required String other,
    Map<String, Object?> values = const {},
  }) =>
      translate(count == 1 ? one : other, values: {'count': count, ...values});
}

String tr(String source, {Map<String, Object?> values = const {}}) =>
    RitualI18n.translate(source, values: values);

String trPlural(
  int count, {
  required String one,
  required String other,
  Map<String, Object?> values = const {},
}) => RitualI18n.plural(count, one: one, other: other, values: values);
