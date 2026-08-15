# Features and Settings

## Appearance

| Option | Choices | Default | Effect |
| --- | --- | --- | --- |
| Color theme | System, Light, Dark | System | Changes the complete app theme immediately. System follows Android. |

## Experience

| Option | Default | Effect |
| --- | --- | --- |
| Daily streaks | On | Shows current/best streak, weekday progress, and first-entry celebrations. Turning it off preserves streak history. |
| Welcome setup | Completed after first run | Reopens the guided customization flow. |

## Meal reflection

Each scale is independent and off by default. Enabled scales use integer values from 1 through 5 and may still be left unanswered on an individual entry.

| Option | Asked when | End labels |
| --- | --- | --- |
| Hunger before eating | Before feelings | Not hungry → Very hungry |
| Craving before eating | Before feelings | No craving → Very strong |
| Fullness after eating | After feelings | Still hungry → Very full |

Meal types are Breakfast, Lunch, Dinner, and Snack. Feelings are Happy, Calm, Energized, Comforted, Satisfied, Social, Rushed, Distracted, and Still hungry. Multiple feelings may be selected. Selection changes color and border without adding a checkmark, so neighboring labels do not move.

## Privacy

| App lock | Behavior |
| --- | --- |
| No app lock | Opens directly. |
| Device security (recommended) | Uses Android-supported fingerprint, device PIN, or pattern through the system authentication prompt. |
| Ritual PIN | Uses a separate four-digit PIN. After five failed attempts, input is blocked for 30 seconds. |

The lock waits five seconds after the app is backgrounded. Brief notification-shade use therefore does not immediately lock. The system camera is a trusted interruption and does not cause an extra prompt on return. When lock is enabled, Android receives a privacy-shield signal so journal content is not left visible behind the lock surface.

## Reminders

**Mindful meal reminders** is off by default and requests notification permission when enabled. Breakfast, lunch, dinner, and empty-day times are editable whether reminders are on or off. See [[Reminders and Streaks]] for the scheduling rules.

## Your data

- **Export journal:** full ZIP with metadata and original photo bytes; choose recommended AES-256 password protection or a warned standard ZIP.
- **Export report:** PDF with photos or CSV without photos; choose 7 days, 30 days, or a custom inclusive range and preview its entry count.
- **Import Ritual ZIP:** validates the archive before making database changes and skips duplicates.
- **Delete all journal data:** destructive, confirmed removal of entries, photos, highlights, and streak history.

Settings such as theme, reminder times, reflection choices, and onboarding completion use Android preferences. The Ritual PIN hash and salt use secure storage. Journal content uses the local SQLite database and private files.

## Share a reflection

The Journal share button opens a local card composer. The user selects one to four of the twelve most recent moments and can include the current streak when streaks are enabled. The rendered card contains only those photos, an optional streak, the current month, and a **Made with Ritual** watermark. It deliberately omits meal metadata, feelings, notes, exact dates, and places. Android's share sheet receives a temporary PNG, which Ritual deletes after the share flow.

## About Ritual

**Support Ritual** explains that the app is free forever and that optional support unlocks no features, badge, early access, priority, or other benefit. **Visit support page** opens `ritualapp.nishkamk.com/support/` in the device browser. Ritual does not send journal data or payment information during this handoff.
