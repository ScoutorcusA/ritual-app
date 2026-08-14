# Reminders and Streaks

## Custom reminder times

Defaults are Breakfast 9:30 AM, Lunch 1:30 PM, Dinner 7:30 PM, and Empty-day check-in 9:30 PM. Each time can be changed in Settings or the welcome flow. Times use the device's local time zone and display in the Android locale's 12- or 24-hour format.

## Dynamic reminder rules

Ritual schedules a rolling 14-day window of local notifications and refreshes it when journal entries change, reminder settings change, or the app resumes.

For each day:

1. A breakfast reminder is omitted if Breakfast is already logged for that date.
2. Lunch and dinner follow the same meal-type rule.
3. Snack entries do not suppress meal-type reminders.
4. The empty-day check-in is scheduled only when the date has no entries of any type.
5. A reminder whose configured time has already passed is not scheduled.
6. Disabling reminders cancels Ritual's pending meal-reminder notifications.

Notifications use an Android channel named **Meal reminders**, default importance, and inexact idle scheduling. Android may batch or delay them to save battery. Ritual never sends reminder data to a server.

## Permission flow

On supported Android versions, enabling reminders first checks whether notifications are already allowed. If not, Ritual invokes the Android permission prompt. A denial leaves the toggle off and offers a path to app notification settings. Permission and the Ritual toggle are separate: both must be enabled.

## Streak calculation

A streak counts distinct local calendar dates with at least one entry; multiple meals on one day count once. The current streak remains active when the latest logged day is today or yesterday, which lets the user begin the current day without losing yesterday's streak. A gap of two or more days resets current progress. Best progress is retained separately.

The journal header shows Monday through Sunday. Completed days have a check; today has a highlighted ring; future days are muted. Current and best counts remain above the weekday row.

## Celebrations

The short overlay appears only after the first entry manually added on a calendar day, automatically closes after a few seconds, and includes a skip button. Special copy is used at 7, 30, 100, and 365 days. Day 1 has first-streak copy; other days use the standard count. Imports never trigger the overlay. Disabling Daily streaks hides the card and celebrations without deleting progress.
