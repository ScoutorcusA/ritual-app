# Architecture and Data

## Technology

Ritual is a Flutter/Dart application with an Android-first platform target. State uses `ChangeNotifier` controllers. Persistent journal data uses `sqflite`; files use `path_provider`; camera capture uses `image_picker`; notifications use `flutter_local_notifications` plus `timezone`; app lock uses `local_auth` and `flutter_secure_storage`.

## Source layout

| Path | Responsibility |
| --- | --- |
| `lib/controllers/` | Journal and settings state, persistence orchestration |
| `lib/data/` | SQLite repository and private photo lifecycle |
| `lib/insights/` | Deterministic insight engine |
| `lib/models/` | Entries, drafts, imports, and export ranges |
| `lib/screens/` | Welcome, journal, Browse, editor, detail, daily journal, settings |
| `lib/services/` | Location, reminders, ZIP, PDF, and CSV |
| `lib/utils/` | Day grouping, summaries, and streak calculation |
| `lib/widgets/` | App lock, cards, collages, insight and streak overlays |

`main.dart` initializes notifications and settings before rendering, creates the SQLite-backed journal controller, synchronizes reminders, and places either onboarding or the journal shell behind the app-lock gate.

## SQLite schema (version 5)

### `meals`

`id`, private `image_path`, `meal_type`, JSON `feelings`, `note`, epoch `created_at`, optional `latitude`, `longitude`, `location_label`, unique nullable `import_fingerprint`, and optional `hunger_level`, `fullness_level`, `craving_level`.

### `preferences`

Key/value data currently used for `best_streak`. UI settings are kept separately through Android shared preferences.

### `daily_highlights`

Maps a local `day_key` to one `meal_id`, making a randomly chosen calendar highlight stable.

## Entry lifecycle

1. Camera returns a temporary `XFile`.
2. Repository copies it to `ritual_photos/meal_<microseconds>.<extension>`.
3. Editor creates a `MealDraft`; repository inserts it and returns a `MealEntry`.
4. Journal controller updates in-memory ordering, streaks, and listeners.
5. Main resynchronizes dynamic reminders.

Canceling the editor discards the copied private photo. Deleting an entry deletes both row and file. Delete-all removes rows/highlights/best streak in a transaction and recursively deletes only the explicit `ritual_photos` directory.

## Derived data

Daily grouping, feeling summaries, top-level journal summary, insights, and current streak are recalculated from entries. Best streak and selected calendar highlights are persisted. Reminder schedules are regenerated for the next 14 days rather than stored as business records.
