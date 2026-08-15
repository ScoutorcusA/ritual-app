# Ritual Privacy Policy

**Effective date: August 14, 2026**  
**Last updated: August 14, 2026**

Ritual is a mindful food photo journal developed and maintained by the Ritual project ("Ritual," "we," "us," or "our"). This policy explains how the Ritual Android application accesses and handles information.

## Summary

Ritual is designed to keep journal data on the user's device. Ritual does not require an account and does not operate a server that receives journal entries. We do not sell personal information, show advertising, build advertising profiles, or include analytics or crash-reporting SDKs.

## Information handled by the app

Depending on the features a user chooses, Ritual may access or store:

- meal photographs taken through the device camera;
- meal type, feelings, notes, date, and time;
- optional hunger, craving, and fullness ratings;
- optional precise or approximate device coordinates and a place label;
- app preferences, reminder times, streak progress, and calendar highlights;
- an optional four-digit Ritual PIN hash and salt, or the result of Android device authentication.

This information is used only to provide the journal, Browse views, local insights, reminders, streaks, security, and exports requested by the user.

## Local storage and transmission

Journal records are stored in a SQLite database inside Ritual's Android application sandbox. Captured photographs are copied into app-private storage and are not added to Android's shared photo gallery. Preferences remain on the device, and Ritual PIN material is stored through Android-backed secure storage.

Ritual does not transmit journal entries, photographs, ratings, notes, coordinates, identifiers, diagnostics, or usage activity to Ritual or to advertising or analytics companies. The release application does not request general internet access.

When a user requests a place name, Ritual calls Android's system geocoding service. The device or its configured geocoding provider may process coordinates to return a place description. Ritual does not control that provider's data practices; those practices are governed by the device provider's applicable privacy terms. A user can avoid geocoding by entering a place manually or by omitting location.

## Permissions

- **Location:** Requested only after the user selects **Use current location** while editing an entry. Ritual uses foreground location for that user-initiated request and does not request background location.
- **Notifications:** Requested only if the user enables meal reminders. Notifications are scheduled locally.
- **Camera:** Used when the user chooses to photograph a meal through Android's camera flow.
- **Device authentication:** Used only when the user enables the recommended device-security app lock. Fingerprint templates and device credentials are handled by Android and are not provided to Ritual.

## Exports and sharing

Ritual creates ZIP, PDF, or CSV files only after a user explicitly requests an export and chooses where to save it. ZIP and PDF exports may contain sensitive journal information; CSV contains journal details but no photos or internal image paths. Exports are not encrypted. After export, the selected storage provider, receiving application, recipient, and user control the file. Users should store and share exports carefully.

Ritual does not automatically share data with healthcare professionals. A user may independently choose to share an exported report with a dietitian, doctor, or another recipient.

## Optional support

Ritual is free forever. Optional sponsorship unlocks no app features, status, special access, or other benefits. If a user chooses **Visit support page**, Android opens `ritualapp.nishkamk.com` in the device browser. The Ritual app does not send journal data, identifiers, or payment information during this handoff.

If the user continues to GitHub Sponsors, GitHub processes the sponsorship and any information the user provides under its own terms and privacy statement. Ritual does not receive payment-card details. Leaving the app to visit these pages is always optional.

## Retention and deletion

Information remains on the device until the user deletes an entry, selects **Settings → Delete all journal data**, clears the app's storage through Android, or uninstalls Ritual. Deleting an entry deletes its app-private photo. Delete-all removes journal entries, private meal photos, saved calendar highlights, and streak history while retaining general app preferences.

Because Ritual has no user accounts or server-side journal database, there is no remote account data for Ritual to delete. Users should separately delete any files they previously exported or shared.

## Security

Ritual relies on Android's application sandbox and offers optional device authentication or a separate Ritual PIN. Android backup is disabled. These safeguards reduce unauthorized access but no device or storage system can be guaranteed completely secure. Ritual's local database and photographs are not individually encrypted by the app, and exported files are unencrypted.

## Health information and disclaimer

Meal records and hunger, craving, fullness, or feeling entries may be considered sensitive health-related information. They remain locally controlled as described above.

Ritual is a personal reflection tool. It is not a medical device and does not diagnose, treat, cure, or prevent any disease or medical condition. Its summaries and insights identify simple journal patterns and are not medical advice. Users should consult a qualified healthcare professional for medical advice, diagnosis, or treatment and should not delay professional care because of information shown by Ritual.

## Children

Ritual is not specifically directed to children under 13, and we do not knowingly collect children's personal information on a server. A parent or guardian should supervise a child's use of any health-related journaling application and any sharing of exports. The intended Google Play target audience should exclude children unless the app and listing are separately reviewed for Families policy compliance.

## Changes to this policy

We may update this policy when Ritual's features or legal obligations change. The effective date and last-updated date will be revised, and material changes will be reflected in the app or release documentation. Continued use after an update is subject to the updated policy.

## Contact

For privacy questions, open an issue in the [Ritual GitHub repository](https://github.com/ScoutorcusA/ritual-app/issues) without including meal photos, health details, location, or other sensitive information. The developer contact email shown on Ritual's Google Play listing may also be used for private inquiries.
