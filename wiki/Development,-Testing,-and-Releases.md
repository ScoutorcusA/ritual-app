# Development, Testing, and Releases

## Local checks

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Local release builds fall back to Android's debug key unless signing environment variables are present. Do not ship a debug-key fallback to Google Play.

## Test coverage

Automated tests cover models and persistence choices, daily grouping and summaries, stable calendar highlights, streak calculation/preferences/celebrations, app-lock lifecycle and privacy behavior, dark-mode and stable labels, location models, reminder permission state and planning, custom times, reflection scales, every insight category, ZIP round trips and hostile archives, PDF contents/ranges, CSV escaping and formula safety, and Settings UI.

Sample PDF/CSV files use synthetic entries. Sample PDF color blocks are generated stand-ins; in-app reports load actual meal photos.

## GitHub Actions APK release

Every push to `main` runs `.github/workflows/android-release.yml`. The workflow installs pinned Flutter and Java versions, resolves dependencies, runs analysis and all tests, validates signing secrets, builds a monotonically versioned signed APK, uploads a 90-day workflow artifact, creates a permanent versioned prerelease, and updates the rolling `ritual-latest` prerelease with APK and SHA-256 checksum.

The `ritual-latest` asset is intentionally replaced so one stable URL always downloads the newest APK. Older builds remain attached to their unique versioned GitHub releases instead of disappearing.

Required repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

PKCS12 keystores commonly use one password for the store and private-key entry, but the workflow accepts both fields. Never commit `.jks`, `.keystore`, `key.properties`, passwords, or Base64 key material.

## Versioning

`pubspec.yaml` supplies the human version and local build number. CI overrides the Android build number with a value derived from the workflow run so each published APK can update the previous one. APK updates must use the same signing certificate.

## Wiki source

The Markdown files in `/wiki` are the canonical wiki source. GitHub hosts wikis in a separate `ritual-app.wiki.git` repository. `.github/workflows/publish-wiki.yml` copies these pages there after a push to `main`; the repository's **Wiki** feature must be enabled. Keeping the source in the main repository makes documentation reviewable with code changes.
