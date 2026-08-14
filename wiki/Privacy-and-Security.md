# Privacy and Security

## Local-only design

Ritual has no login, backend, cloud sync, advertisements, subscriptions, analytics SDK, or automatic telemetry. Journal data is stored in the app's Android sandbox:

- SQLite database: `ritual.db`
- private photo directory: `ritual_photos/`
- ordinary preferences: theme, reminder state/times, streak display, reflection toggles, onboarding completion
- secure storage: Ritual PIN salt and repeated SHA-256 hash

Captured files are copied into the app-private documents directory rather than Android shared media storage, so they do not appear in Gallery. Android backup is disabled. Uninstalling the app removes local journal data unless the user first exports it.

## Permissions

- **Camera:** requested by the image picker when taking a meal photo.
- **Location:** requested only when the user asks to add current location.
- **Notifications:** requested only when reminders are enabled.
- **Device authentication:** invoked only when device lock is selected or used to unlock.

Location obtains latitude/longitude first and then uses Android reverse geocoding to derive a human-readable label. If geocoding is unavailable, coordinates may still be saved and the user can enter a place manually. Manual places do not require coordinates.

## App lock

Device security delegates authentication to Android. Ritual never receives the fingerprint or the device credential. The separate Ritual PIN must be exactly four digits. Its random 16-byte salt and derived hash are stored through secure storage; the plaintext PIN is not saved. Comparison avoids early exit, and five failures trigger a 30-second cooldown.

The app locks after remaining backgrounded for five seconds. Camera capture is explicitly treated as trusted. The lock surface replaces the journal instead of drawing transparently over it, and the native Android privacy shield is enabled whenever app lock is on.

## Important limitations

App-private storage is sandboxed but journal photos and the SQLite database are not individually encrypted by Ritual. A compromised/rooted device may bypass normal Android protections. Screenshots and external exports require separate care. ZIP, PDF, and CSV exports are intentionally unencrypted for portability and display a warning before export.

Ritual is a reflective journal, not a medical device. Insights are static pattern descriptions, not diagnoses or treatment advice.
