# Privacy and Security

## Local-only design

Ritual has no login, backend, cloud sync, advertisements, subscriptions, analytics SDK, or automatic telemetry. Journal data is stored in the app's Android sandbox:

- SQLite database: `ritual.db`
- private photo directory: `ritual_photos/`
- ordinary preferences: theme, reminder state/times, streak display, reflection toggles, onboarding completion
- a bounded diagnostics log containing recent technical outcomes, with no journal content, photos, place names, or coordinates

Captured files are copied into the app-private documents directory rather than Android shared media storage, so they do not appear in Gallery. Android backup is disabled. Uninstalling the app removes local journal data unless the user first exports it.

## Permissions

- **Camera:** requested by the image picker when taking a meal photo.
- **Approximate location:** requested only when the user asks to add a broad city-and-country label.
- **Notifications:** requested only when reminders are enabled.
- **Device authentication:** invoked only when device lock is selected or used to unlock.

Location obtains an approximate position, passes it to Android's system geocoder, and retains only the resulting city-and-country label. Newly obtained raw coordinates are not saved. If Android's geocoder is unavailable, Ritual reports the actual failure and offers manual city entry. Older entries or imported archives may still contain coordinates created by earlier versions.

The diagnostics log keeps at most 120 timestamped technical events in ordinary app preferences. It is never transmitted automatically. **Copy debug log** places it on the Android clipboard only when selected, after which the user controls where it is pasted. Uninstalling or clearing Ritual's app storage removes it.

## App lock

Device security delegates authentication to Android. Ritual never receives the fingerprint or the device credential. When app lock is enabled, Ritual immediately replaces private screens with a privacy cover whenever the app is no longer active and dismisses private text input. Returning after five seconds or longer requires Android device authentication.

The app locks after remaining backgrounded for five seconds. Camera capture is explicitly treated as trusted. The lock surface replaces the journal instead of drawing transparently over it, and the native Android privacy shield is enabled whenever app lock is on.

## Important limitations

App-private storage is sandboxed but journal photos and the SQLite database are not individually encrypted by Ritual. A compromised/rooted device may bypass normal Android protections. Screenshots and external exports require separate care. ZIP backups offer optional AES-256 password protection; PDF, CSV, and standard ZIP exports remain unencrypted for portability and display an appropriate warning.

Ritual is a reflective journal, not a medical device. Insights are static pattern descriptions, not diagnoses or treatment advice.
