# Ritual

Ritual is a private, mindful food photo journal built with Flutter. It helps people notice meals, feelings, hunger, cravings, fullness, and eating patterns without counting calories or labeling food as good or bad.

The app is Android-first, works entirely on-device, and has no account, cloud sync, advertisements, subscriptions, analytics SDK, or feature paywall.

> **Project status:** Active development. Ritual is currently a personal Android app and is not yet published on Google Play.

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

## Appearance and accessibility

- Light, dark, or system theme
- Dark-mode-safe meal, feeling, and gallery filters
- Large tappable calendar days and journal cards
- Semantic labels for day cards and moment counts
- Minimal, photo-forward visual design

## Privacy model

Ritual stores its SQLite database and captured photos inside the app’s private storage. Other gallery apps do not receive those photos, and Ritual does not upload journal data to a server.

App-private storage is not the same as encrypting every database or image file at rest. Device security, Ritual’s optional app lock, and Android’s application sandbox provide the main protection. Exported files leave that sandbox and are deliberately unencrypted for portability.

Location and notification permissions are requested only when their related features are enabled. Location is optional, and a journal entry can use a manual place without storing coordinates.

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

The current Android release build is signed with the debug key for local installation. Before publishing, the project still needs:

- A private production upload key and Play App Signing configuration
- An Android App Bundle (`flutter build appbundle`)
- A public privacy policy linked from the app and Play listing
- Accurate Data Safety and Health Apps declarations
- Store screenshots, listing copy, support details, and closed testing as required for the developer account

Do not publish an APK signed with the current debug signing configuration.
