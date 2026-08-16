import 'dart:convert';
import 'dart:io';

const _sourceDirectory = 'translations';
const _websiteDirectory = 'web/assets/i18n';

Future<void> main(List<String> arguments) async {
  final command = arguments.firstOrNull ?? 'check';
  final catalog = await _extractEnglishSources();
  switch (command) {
    case 'extract':
      await _writeEnglishCatalog(catalog);
      await _syncWebsiteCatalogs();
      stdout.writeln('Updated the English catalog and website locale files.');
    case 'sync-web':
      await _syncWebsiteCatalogs();
      stdout.writeln('Updated website locale files.');
    case 'check':
      await _check(catalog);
      stdout.writeln('Localization catalogs are complete and synchronized.');
    default:
      stderr.writeln(
        'Usage: dart run tool/localization_tool.dart [extract|sync-web|check]',
      );
      exitCode = 64;
  }
}

Future<Set<String>> _extractEnglishSources() async {
  final values = <String>{
    'Happy',
    'Calm',
    'Energized',
    'Comforted',
    'Satisfied',
    'Social',
    'Rushed',
    'Distracted',
    'Still hungry',
    'Stored only on this device',
    'No account or cloud required',
    'Photos stay out of your gallery',
  };
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  final translatedCall = RegExp(
    r'''\btr\(\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''',
    dotAll: true,
  );
  final pluralValue = RegExp(
    r'''\b(?:one|other):\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''',
    dotAll: true,
  );
  final archiveMessage = RegExp(
    r'''RitualArchiveException\(\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''',
    dotAll: true,
  );
  for (final file in dartFiles) {
    final source = await file.readAsString();
    for (final match in translatedCall.allMatches(source)) {
      values.add(_decodeDart(match.group(1) ?? match.group(2)!));
    }
    for (final match in pluralValue.allMatches(source)) {
      values.add(_decodeDart(match.group(1) ?? match.group(2)!));
    }
    for (final match in archiveMessage.allMatches(source)) {
      values.add(_decodeDart(match.group(1) ?? match.group(2)!));
    }
  }

  final htmlFiles = Directory('web')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.html'));
  final textNode = RegExp(r'>([^<>]+)<', multiLine: true);
  final attribute = RegExp(r'''\b(?:aria-label|title|alt|content)="([^"]+)"''');
  for (final file in htmlFiles) {
    final source = await file.readAsString();
    for (final match in textNode.allMatches(source)) {
      final value = _normalizeHtml(match.group(1)!);
      if (_translatable(value)) values.add(value);
    }
    for (final match in attribute.allMatches(source)) {
      final value = _normalizeHtml(match.group(1)!);
      if (_translatable(value)) values.add(value);
    }
  }

  final manifest =
      jsonDecode(await File('web/site.webmanifest').readAsString())
          as Map<String, dynamic>;
  for (final key in ['name', 'short_name', 'description']) {
    final value = manifest[key] as String?;
    if (value != null && _translatable(value)) values.add(value);
  }
  values.add('Language');
  return values;
}

String _decodeDart(String value) => value
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\\', r'\');

String _normalizeHtml(String value) => value
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .trim();

bool _translatable(String value) {
  if (value.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(value)) return false;
  if (value.startsWith('http') || value.startsWith('#')) return false;
  if (value == 'website' || value == 'summary_large_image') return false;
  if (value.contains('/') && !value.contains(' ')) return false;
  return true;
}

Future<void> _writeEnglishCatalog(Set<String> extracted) async {
  final file = File('$_sourceDirectory/en.json');
  final existing =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final existingStrings = (existing['strings'] as Map<String, dynamic>?) ?? {};
  final keys = {...existingStrings.keys, ...extracted}.toList()..sort();
  final strings = <String, String>{
    for (final key in keys) key: existingStrings[key] as String? ?? key,
  };
  final output = {'_meta': existing['_meta'], 'strings': strings};
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
}

Future<void> _syncWebsiteCatalogs() async {
  final destination = Directory(_websiteDirectory);
  await destination.create(recursive: true);
  final sourceFiles = Directory(
    _sourceDirectory,
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));
  for (final source in sourceFiles) {
    final name = source.uri.pathSegments.last;
    await source.copy('$_websiteDirectory/$name');
  }
  final definitions =
      jsonDecode(await File('$_sourceDirectory/manifest.json').readAsString())
          as Map<String, dynamic>;
  for (final row in definitions['locales'] as List<dynamic>) {
    final code = (row as Map<String, dynamic>)['code'] as String;
    await File(
      '$_websiteDirectory/site-$code.webmanifest',
    ).writeAsString(await _localizedWebManifest(code));
  }
}

Future<void> _check(Set<String> extracted) async {
  final manifestFile = File('$_sourceDirectory/manifest.json');
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final definitions = manifest['locales'] as List<dynamic>;
  final english = await _stringsFor('en');
  final missingEnglish = extracted.difference(english.keys.toSet());
  if (missingEnglish.isNotEmpty) {
    throw StateError(
      'English catalog is missing:\n${missingEnglish.map((value) => '  - $value').join('\n')}',
    );
  }
  for (final row in definitions) {
    final code = (row as Map<String, dynamic>)['code'] as String;
    final localized = await _stringsFor(code);
    final missing = english.keys.toSet().difference(localized.keys.toSet());
    final extra = localized.keys.toSet().difference(english.keys.toSet());
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw StateError(
        '$code does not match English. Missing: ${missing.length}; extra: ${extra.length}.',
      );
    }
    final webCopy = File('$_websiteDirectory/$code.json');
    if (!await webCopy.exists() ||
        await webCopy.readAsString() !=
            await File('$_sourceDirectory/$code.json').readAsString()) {
      throw StateError('Website copy for $code is out of date.');
    }
    final localizedSiteManifest = File(
      '$_websiteDirectory/site-$code.webmanifest',
    );
    if (!await localizedSiteManifest.exists() ||
        await localizedSiteManifest.readAsString() !=
            await _localizedWebManifest(code)) {
      throw StateError('Website manifest for $code is out of date.');
    }
  }
  final manifestCopy = File('$_websiteDirectory/manifest.json');
  if (!await manifestCopy.exists() ||
      await manifestCopy.readAsString() != await manifestFile.readAsString()) {
    throw StateError('Website locale manifest is out of date.');
  }
  await _checkForHardCodedUiText();
}

Future<void> _checkForHardCodedUiText() async {
  final violations = <String>[];
  final directText = RegExp(
    r'''(?<![A-Za-z])(?:pdf\.)?Text\(\s*(?:const\s+)?(?:'([^']*[A-Za-z][^']*)'|"([^"]*[A-Za-z][^"]*)")''',
  );
  final directAttribute = RegExp(
    r'''\b(?:tooltip|labelText|hintText|helperText|helpText|saveText):\s*(?:'([^']*[A-Za-z][^']*)'|"([^"]*[A-Za-z][^"]*)")''',
  );
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in dartFiles) {
    final lines = await file.readAsLines();
    for (final (index, line) in lines.indexed) {
      if (directText.hasMatch(line) || directAttribute.hasMatch(line)) {
        violations.add('${file.path}:${index + 1}: ${line.trim()}');
      }
    }
  }
  if (violations.isNotEmpty) {
    throw StateError(
      'User-facing text bypasses tr():\n${violations.join('\n')}',
    );
  }
}

Future<Map<String, dynamic>> _stringsFor(String code) async {
  final value =
      jsonDecode(await File('$_sourceDirectory/$code.json').readAsString())
          as Map<String, dynamic>;
  return value['strings'] as Map<String, dynamic>;
}

Future<String> _localizedWebManifest(String code) async {
  final source =
      jsonDecode(await File('web/site.webmanifest').readAsString())
          as Map<String, dynamic>;
  final strings = await _stringsFor(code);
  final localized = Map<String, dynamic>.from(source);
  for (final key in ['name', 'short_name', 'description']) {
    final value = source[key] as String?;
    if (value != null) localized[key] = strings[value] ?? value;
  }
  return '${const JsonEncoder.withIndent('  ').convert(localized)}\n';
}
