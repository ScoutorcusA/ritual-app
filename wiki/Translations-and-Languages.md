# Translations and Languages

Ritual keeps the app and website translation source in the top-level `translations/` directory. English source phrases are the stable keys, and volunteers translate only the values. The app, reminders, CSV/PDF labels, privacy/support screens, and website all use the same catalog.

## Add a language

1. Copy `translations/en.json` to a file named with the locale code, such as `translations/es.json` or `translations/pt-BR.json`.
2. In `_meta`, update `locale`, the language's own display `name`, and `direction` (`ltr` or `rtl`).
3. Translate every value in `strings`. Do not change the English keys.
4. Preserve placeholders exactly, including `{count}`, `{date}`, and any other text inside braces. Preserve intentional newlines.
5. Add the locale to `translations/manifest.json` using the same code, name, and direction.
6. From the repository root, run:

   ```sh
   dart run tool/localization_tool.dart sync-web
   dart run tool/localization_tool.dart check
   flutter test
   ```

The website catalogs and localized web-app manifests under `web/assets/i18n/` are generated. Do not translate them directly. When more than one locale is present, the website shows a language selector; otherwise it follows the only available language. The app chooses the closest supported Android locale and falls back to English.

## When English copy changes

Run:

```sh
dart run tool/localization_tool.dart extract
```

This adds new app and website phrases to the English catalog without deleting existing entries, then refreshes the website copies. The completeness check fails if a locale is missing or adds keys, if the website copy is stale, or if straightforward user-facing Flutter text bypasses the translation function.

## Review checklist

- Test on a narrow phone and the website at mobile width; translations often expand.
- Check reminders and notification actions on a real Android device.
- Export PDF and CSV samples, including long reflections and multiple snacks.
- Check right-to-left layout when `direction` is `rtl`.
- Keep Ritual's calm, nonjudgmental tone rather than translating word-for-word when that would sound unnatural.
- Never use real journal entries, photos, places, or exports in translation screenshots or bug reports.
