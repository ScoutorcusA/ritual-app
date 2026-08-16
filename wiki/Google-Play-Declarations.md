# Google Play Declarations

**Prepared for Ritual 1.6.0+11 on August 16, 2026.** Re-audit these answers whenever code, SDKs, permissions, monetization, sharing behavior, or network behavior changes. See [[Development, Testing, and Releases]] for the internal/closed-testing and app-signing workflow.

## Privacy policy URL

Use this in **Play Console → Policy → App content → Privacy policy** and in the store listing where requested:

`https://ritualapp.nishkamk.com/privacy/`

The website must be deployed so this URL is active, publicly accessible, non-geofenced, and readable without a login. Do not submit while the URL returns 404 or before HTTPS is working.

## Data Safety form

### Data collection and sharing

| Play Console question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |

Why: the production app has no account, backend, analytics, ads, crash reporting, or general internet permission. Journal text, health-related ratings, photos, and optional location remain on the device. Google defines collection as transmitting data off the device and excludes local-only access/processing.

Do **not** select Photos and videos, Health and fitness info, Other user-generated content, Approximate location, or Precise location in the Data Safety data-types screen for the audited build. Those types are accessed locally, but they are not transmitted by Ritual. Android permission disclosure is separate from Data Safety.

User-directed ZIP/PDF/CSV export and share-card use are not automatic collection by Ritual. The user chooses the destination or receiving application. The privacy policy must distinguish password-protected ZIP backups from unencrypted standard ZIP, PDF, CSV, and intentionally shared card images.

### Security-practices questions

Play Console can change which follow-up questions appear. Use these answers when shown:

| Question | Answer | Reason |
| --- | --- | --- |
| Is all user data collected by your app encrypted in transit? | **Not applicable / no data is collected**, if available | Ritual does not transmit collected user data. Do not claim transport encryption for nonexistent collection. |
| Do you provide a way for users to request deletion? | **Yes** | **Settings → Delete all journal data** deletes entries, photos, highlights, and streak history. There is no account or remote data. |
| Has the app been independently validated against a global security standard? | **No** | No independent audit or certification has been completed. |
| Is the app committed to follow the Play Families policy? | **No**, unless you intentionally enter the Families program | Current intended audience should exclude children. |

### Reconsider “No data collected” if any of these are added

- analytics, crash reporting, telemetry, cloud backup, sync, accounts, or payments processed inside the app;
- a server-based geocoder, AI analysis, image processing, or nutrition API;
- remote notification tokens;
- support uploads or automatic diagnostic logs;
- any SDK that transmits identifiers, app activity, diagnostics, photos, health information, or location.

## Health Apps declaration

In **Play Console → Policy → App content → Health apps**:

1. Select that the app provides health features.
2. Under **Health and fitness**, select **Nutrition and Weight Management**.
3. Do not select Activity and Fitness, Period Tracking, Sleep Management, Stress Management/Relaxation/Mental Acuity, or any Medical category for the current feature set.
4. Do not select **Medical Device Apps**.

Rationale: Google defines Nutrition and Weight Management to include tools for tracking dietary intake and managing diets. Ritual records meals and eating-related reflections even though it intentionally avoids calories and weight-loss targets. Feelings attached to meals do not make Ritual a mental-health or stress-management service because it offers no counseling, treatment, meditation, or mental-health guidance.

### Medical-status answers and disclaimer

| Question | Answer |
| --- | --- |
| Is Ritual a regulated medical device? | **No** |
| Does Ritual diagnose, treat, cure, prevent, or manage a disease or condition? | **No** |
| Does it provide clinical decision support or treatment recommendations? | **No** |
| Does it connect users with healthcare providers? | **No**; users only export a report and decide independently whether to share it. |
| Does it access Health Connect or medical-record APIs? | **No** |

Use this statement in the store listing and keep the equivalent text inside the app:

> Ritual is a personal reflection tool, not a medical device. It does not diagnose, treat, cure, or prevent any disease or medical condition, and its summaries are not medical advice. Consult a qualified healthcare professional for medical advice, diagnosis, or treatment.

## Other Play Console declarations

| Declaration | Current answer |
| --- | --- |
| Contains ads | **No** |
| App access | **All functionality is available without login.** Explain optional app lock; reviewers can leave it disabled. |
| Target audience | **Adults / not directed to children.** Select the age groups matching the final listing strategy and do not enroll in Families without another review. |
| Financial features | **None.** The optional external creator-sponsorship link is not a banking, lending, investing, insurance, cryptocurrency, money-transfer, or other financial-service feature. |
| Government app | **No** |
| News app | **No** |

## Reviewer note

Suggested App access/review note:

> Ritual requires no account. Tap the camera button to create an entry. Location, notifications, reflection scales, streaks, and app lock are optional. Device authentication may be left disabled during review. All journal data and photos are stored locally; Settings includes report export and Delete all journal data.

## Payments policy and optional support

Settings includes an optional **Support Ritual** entry. It opens an explanatory in-app screen, followed by a user-initiated external link to `ritualapp.nishkamk.com/support/`. The support page may lead to the developer's GitHub Sponsors profile.

This is a direct creator contribution rather than an in-app purchase:

- Ritual is free forever and every feature is available without payment.
- Supporting Ritual grants no digital content, badge, credit, early access, priority, recognition, or other benefit.
- Ritual does not process the payment or receive payment-card information.
- The prompt is confined to Settings and does not interrupt journaling.
- The support page must not sell Ritual features or services.

Google Play's Payments FAQ treats a contribution as a peer-to-peer payment, without requiring Play Billing, when 100% goes to the creator and it grants no digital content or service. Recheck that policy before each production submission because regional payment-link programs and wording can change.
