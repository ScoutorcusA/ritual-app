# Ritual

[![Build Android APK](https://github.com/ScoutorcusA/ritual-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/ScoutorcusA/ritual-app/actions/workflows/android-release.yml)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](LICENSE)

[Read the complete Ritual wiki](https://github.com/ScoutorcusA/ritual-app/wiki) for every setting, insight rule, privacy detail, data format, and release workflow.

Ritual is a private, mindful food photo journal built with Flutter. It helps people notice meals, feelings, hunger, cravings, fullness, and eating patterns without counting calories or labeling food as good or bad.

The app is Android-first, works entirely on-device, and has no account, cloud sync, advertisements, subscriptions, analytics SDK, or feature paywall. Ritual is free forever; optional sponsorship unlocks nothing and never changes the app experience.

> **Project status:** Active development. Ritual is currently a personal Android app and is not yet published on Google Play.

## Open source and community

Ritual's source code is licensed under the [Mozilla Public License 2.0](LICENSE). When covered source files are distributed in modified form, those files remain available under the MPL 2.0; the license remains practical for combining Ritual code with separately licensed Android or future iOS components.

The source-code license does not grant rights to the Ritual name, logo, app icon, or visual identity. Read the [trademark policy](TRADEMARKS.md) before publishing a fork. Only maintainer-published packages signed with Ritual's private release identity may be called [official Ritual builds](OFFICIAL_BUILDS.md).

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow the [Code of Conduct](CODE_OF_CONDUCT.md), report vulnerabilities through the [security policy](SECURITY.md), and see the short [public roadmap](ROADMAP.md). Issues labeled [`good first issue`](https://github.com/ScoutorcusA/ritual-app/labels/good%20first%20issue) are intended as approachable starting points.

## What Ritual can do

### Capture and reflect

- Photograph breakfast, lunch, dinner, or a snack from inside the app
- Keep captured photos in app-private storage so they do not appear in Android Gallery
- Add feelings and a written reflection to any entry
- Optionally record hunger before eating, craving before eating, and fullness afterward on independent 1–5 scales
- Add the current location with coordinates and a reverse-geocoded place label
- Enter or correct a place manually when location lookup is unavailable or a custom label is preferred
- Edit or delete individual journal entries

### Revisit the journal

- Group the journal into large daily cards with collages of up to four photos
- Show each day’s date, moment count, and a short feelings summary
- Open a dedicated daily journal containing every entry from that day
- Intermix deterministic insight cards between journal days to surface patterns without making medical conclusions
- Summarize total moments, average entries per logged day, and the median gap between same-day entries

### Browse visually

- Browse a filterable photo gallery by all meals, breakfast, lunch, dinner, or snacks
- Switch to a literal, vertically scrollable monthly calendar
- Use a stable highlight photo for each day; when a day has multiple entries, the selected highlight is saved rather than changing on every visit
- Tap a calendar day to reveal its corresponding entries

### Build a gentle routine

- Track current and best daily streaks
- Celebrate the first manually added entry of each calendar day
- Use special milestone celebrations at 7, 30, 100, and 365 days
- Disable streak progress and celebrations completely from Settings without deleting accumulated progress
- Schedule local meal reminders around breakfast, lunch, and dinner
- Skip reminders for meal types already logged and add a late check-in only when the day is still empty

### Protect private data

- Lock Ritual with Android device authentication, including fingerprint, device PIN, or pattern
- Use a separate four-digit Ritual PIN instead
- Hide journal content behind the authentication screen when the app is locked
- Allow a five-second background grace period so briefly checking the notification shade does not immediately lock the app
- Treat the system camera as a trusted interruption so returning from taking a meal photo does not trigger another authentication request
- Disable Android backup for the app
- Delete all entries, app-private photos, calendar highlights, and streak history from Settings

### Export and restore

- Export the complete journal, metadata, and original photo bytes as a ZIP archive
- Validate archive contents and photos before importing them
- Skip exact duplicates during repeat imports
- Create a chronological PDF report with meal photos and recorded journal details
- Create a CSV report with one entry per row and no images or private image paths
- Choose **Last 7 days**, **Last 30 days**, or an inclusive custom date range for PDF and CSV reports
- See how many entries each range contains before exporting
- Safely encode commas, quotes, multiline reflections, and spreadsheet-like formulas in CSV output

PDF, CSV, and ZIP exports are **not encrypted**. Ritual warns about this before export; exported files should be stored and shared carefully.

### Support continued development

- Open a transparent Support Ritual screen from Settings
- Confirm that Ritual is free forever and identical for supporters and non-supporters
- Optionally continue to the public support page in the device browser
- Keep journal data and payment information out of the sponsorship handoff

## Appearance and accessibility

- Light, dark, or system theme
- Guided first-run setup for theme, reflection prompts, streaks, and reminders
- User-defined breakfast, lunch, dinner, and empty-day reminder times
- Duolingo-style Monday-through-Sunday streak progress
- Dark-mode-safe meal, feeling, and gallery filters
- Large tappable calendar days and journal cards
- Semantic labels for day cards and moment counts
- Minimal, photo-forward visual design

## Privacy model

Ritual stores its SQLite database and captured photos inside the app’s private storage. Other gallery apps do not receive those photos, and Ritual does not upload journal data to a server.

App-private storage is not the same as encrypting every database or image file at rest. Device security, Ritual’s optional app lock, and Android’s application sandbox provide the main protection. Exported files leave that sandbox and are deliberately unencrypted for portability.

Location and notification permissions are requested only when their related features are enabled. Location is optional, and a journal entry can use a manual place without storing coordinates.

The optional support link opens `ritualapp.nishkamk.com` in the device browser. Ritual sends no journal data or payment information. If the user continues to GitHub Sponsors, GitHub handles the sponsorship under its own terms and privacy statement.

Uninstalling Ritual removes its local database and app-private photos. The in-app **Delete all journal data** action provides the same journal cleanup without resetting appearance, app-lock, or reminder preferences.

## Project structure

```text
lib/
├── controllers/   App and journal state
├── data/          SQLite repository and private photo storage
├── insights/      Deterministic journal insight rules
├── models/        Journal and export models
├── screens/       Journal, Browse, editor, details, and settings UI
├── services/      ZIP, PDF, CSV, and local reminder services
├── theme/         Light and dark Ritual themes
├── utils/         Day grouping, summaries, and streak calculations
└── widgets/       Reusable cards, collages, app lock, and celebrations
```

## Run locally

Ritual requires a current Flutter SDK and an Android development environment.

```sh
flutter pub get
flutter run
```

Run the project checks with:

```sh
flutter analyze
flutter test
```

Build an Android APK with:

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Automatic GitHub APK releases

The [Android release workflow](.github/workflows/android-release.yml) runs after every push to `main` and can also be started manually from the repository’s **Actions** tab. It:

1. Installs the project’s pinned Flutter version and dependencies
2. Runs static analysis and the complete test suite
3. Builds an APK with a monotonically increasing Android build number
4. Signs it with the same private key on every run
5. Uploads a 90-day workflow artifact
6. Creates a permanent, versioned prerelease with its APK and SHA-256 checksum
7. Updates the rolling **Ritual Latest** prerelease and its SHA-256 checksum

After the workflow succeeds, download `ritual-latest.apk` from the [Ritual Latest release](https://github.com/ScoutorcusA/ritual-app/releases/tag/ritual-latest). Failed analysis, tests, signing validation, or compilation will prevent a new APK from being published.

The rolling release always points to the newest build, while the [complete Releases page](https://github.com/ScoutorcusA/ritual-app/releases) keeps each versioned build available. This makes the default download simple without replacing the older published APKs.

Only APKs produced by this workflow, published by the maintainer, and signed with Ritual's private release key are [official Ritual builds](OFFICIAL_BUILDS.md). Local, fork, debug, pull-request, and third-party APKs are unofficial even when built from unchanged source.

## Website

The static Ritual website lives in [`web/`](web/) and is prepared for `ritualapp.nishkamk.com`. It includes the landing page, public privacy policy, direct latest-APK link, custom-domain files, and a manual GitHub Pages deployment workflow. See [`web/README.md`](web/README.md) for the hosting steps.

### One-time signing setup

Android only permits an APK to update an installed app when both versions use the same signing key. Create one private key and keep at least two secure backups; losing it means future APKs cannot update existing installations.

Generate a key locally:

```sh
keytool -genkeypair -v \
  -keystore ritual-release.jks \
  -alias ritual \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

In GitHub, open **Settings → Secrets and variables → Actions** and create these repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The complete `ritual-release.jks` file encoded as one Base64 string |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password entered above |
| `ANDROID_KEY_ALIAS` | `ritual`, or the alias chosen above |
| `ANDROID_KEY_PASSWORD` | The private-key password entered above |

Encode the keystore on macOS and copy it to the clipboard with:

```sh
base64 -i ritual-release.jks | pbcopy
```

On Linux:

```sh
base64 -w 0 ritual-release.jks
```

The workflow intentionally fails with a clear message when any signing secret is absent. Keystores are ignored by Git and must never be committed.

> **First CI installation:** An APK signed by the new GitHub key cannot update an older APK signed with Android’s debug key. Export a Ritual ZIP, uninstall the debug-signed build, install `ritual-latest.apk`, and import the ZIP once. Later GitHub APKs will update in place and preserve app data.

## Testing

The automated suite covers journal grouping, calendar highlights, streak calculations and preferences, app-lock lifecycle behavior, dark-mode labels, location models, reminder planning, reflection scales, summaries, insight rules, ZIP round trips, export date boundaries, PDF creation, and CSV safety.

```sh
flutter test
```

Sample synthetic exports used for layout and interoperability checks are stored in:

- `output/pdf/ritual-sample-clinician-report.pdf`
- `output/csv/ritual-sample-journal.csv`

The solid-color images in the sample PDF are deliberately generated test images. Reports created inside Ritual use the journal’s actual app-private meal photos.

## Before publishing to Google Play

Local release builds fall back to Android’s debug key unless the signing environment variables used by the GitHub workflow are provided. GitHub release builds use the stable private key configured in repository secrets. Before publishing to Google Play, the project still needs:

- Play App Signing configuration and a decision on whether the GitHub key will also serve as the Play upload key
- An Android App Bundle (`flutter build appbundle`)
- A public privacy policy linked from the app and Play listing
- Accurate Data Safety and Health Apps declarations
- Store screenshots, listing copy, support details, and closed testing as required for the developer account

Do not publish an APK produced by the local debug-key fallback.
