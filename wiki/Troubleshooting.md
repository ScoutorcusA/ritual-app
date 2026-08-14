# Troubleshooting

## Reminder toggle will not stay on

Confirm Android **Settings → Apps → Ritual → Notifications** is allowed, then return and toggle reminders again. On Android versions with runtime notification permission, Ritual should show the system prompt the first time. Battery optimization can delay inexact alarms even when permission is allowed. Also verify the Meal reminders notification channel is enabled.

## Location has coordinates but no place name

GPS and reverse geocoding are separate Android services. Coordinates can succeed while the platform geocoder fails because the service is unavailable, offline, rate-limited, or cannot resolve that coordinate. Retry with connectivity or enter a place manually. A manual label is valid without coordinates.

## App asks for authentication after taking a photo

Current builds mark camera capture as a trusted interruption. Update to the latest APK if an older build still locks on return. Normal background use longer than five seconds should lock when app lock is enabled.

## Photos appear as solid colors in the sample PDF

That is intentional for repository QA samples. The sample report generator creates synthetic colored images. PDFs exported inside Ritual read each selected entry's private meal photo.

## An APK will not update the installed app

The signing certificates differ or the new Android version code is not higher. Export a ZIP before uninstalling. For the one-time move from a debug-signed build to the stable GitHub-signed build, export, uninstall, install `ritual-latest.apk`, and import. Later APKs signed by the same GitHub key update in place.

## Import is rejected

Ritual rejects corrupt archives, changed manifests/photos, unsupported schema versions, unsafe paths, invalid field values, and files beyond safety limits. Use an unmodified ZIP exported by Ritual. Repeat imports of identical entries report that they already exist rather than duplicating them.

## Journal is empty after reinstalling

Ritual has no cloud account and Android backup is disabled. Uninstall removes local data. Restore from a previously exported Ritual ZIP.
