# Development, Testing, and Releases

## Local checks

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Local release builds fall back to Android's debug key unless signing environment variables are present. Do not ship a debug-key fallback to Google Play.

## Google Play testing

These steps reflect Google Play requirements checked on August 16, 2026. Recheck Play Console guidance before each release because account, policy, and target-API requirements change.

### 1. Create and verify the developer account

Create the Play Console developer account with accurate identity and contact information and enable 2-Step Verification. Google distinguishes Personal and Organization accounts. Its current account-type guidance says organizations/businesses and providers of health apps should use an Organization account; that route requires a D-U-N-S number. Choose the account type that truthfully represents the publisher and follow any account-specific verification shown in Play Console.

### 2. Decide the signing migration before the first upload

Google Play requires Play App Signing for new apps. Two keys have different roles:

- The **upload key** signs the Android App Bundle sent to Play Console.
- The **app signing key** signs the optimized APKs Google delivers to testers and users.

Ritual's current GitHub APK releases are signed with the maintainer-controlled release key. The simplest Play setup is to use that key as the initial upload key and let Google generate the Play app signing key. However, a Play-signed installation then cannot update an APK installed from GitHub because the signing certificates differ. Existing testers should export a Ritual ZIP, uninstall the GitHub build, install the Play build, and import the ZIP once.

If seamless updates between Play and non-Play distribution are essential, choose **Change signing key** during the first Play App Signing setup and provide the existing maintainer app-signing key using Play Console's current secure key-transfer process. Prefer a separate upload key afterward. Make this decision before the first Play release and keep offline backups of every maintainer-controlled key.

### 3. Build a signed Android App Bundle

Play testing tracks use an Android App Bundle (`.aab`). Configure all four release-signing environment variables used by `android/app/build.gradle.kts`, then run:

```sh
flutter analyze
flutter test
flutter build appbundle --release --build-number 12
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`. Increase the build number for every upload. Never upload a bundle built through the local debug-key fallback. Use `jarsigner -verify -verbose -certs` to confirm the bundle certificate before uploading.

Ritual currently inherits target SDK 36 from its pinned Flutter toolchain. Google requires new phone/tablet apps and updates to target Android 16 (API 36) beginning August 31, 2026, so keep target 36 or newer and confirm the value in Play Console's bundle details.

### 4. Start with Internal testing

In Play Console:

1. Choose **Home → Create app**, enter Ritual's name, select App and Free, add the support email, accept the policy/export declarations, and accept Play App Signing.
2. Open **Testing → Internal testing → Create new release** and upload the signed AAB.
3. On the Testers tab, create an email list, add Google or Google Workspace account addresses, provide a private feedback channel, and save it.
4. Review and roll out the release, then send the opt-in link to testers. Internal tests support up to 100 testers and are normally available within minutes. The app is not searchable; testers need the link.

Internal testing can begin before the full store listing is finished. The first uploaded artifact permanently fixes the Play package name, so confirm `com.nishkamkhanna.ritual` before uploading.

Test at least camera capture/return, notification permission and delivery, approximate/manual place entry, device-authentication lock lifecycle, ZIP export/import, PDF/CSV export, sharing, deletion, dark mode, upgrade from one Play build to the next, and behavior after reboot/time-zone changes.

### 5. Complete setup and run Closed testing

Before Closed testing, complete the Play dashboard tasks, including the store listing and screenshots, countries/regions, privacy-policy URL, App access, Ads, Target audience, Content rating, Data Safety, and Health Apps declarations. Use the answers maintained in [[Google Play Declarations]] and re-audit them against the exact uploaded build.

Create a Closed testing release, add testers by email list or Google Group, publish it, and share the opt-in link. Testers must opt in with the same Google account used on their Android device.

For a Personal developer account created after November 13, 2023, production access currently requires at least 12 testers to remain opted in to the closed test continuously for 14 days. Keep more than 12 testers enrolled to provide a buffer. When Play Console marks the requirement complete, apply for production access from the Dashboard and answer its questions about recruitment, engagement, feedback, fixes, and readiness. Internal testers do not count toward this closed-testing requirement.

### 6. Keep a small release record

For each testing build, retain the version/build number, source commit, AAB checksum, tester group, test dates, feedback themes, crashes or failures, and fixes made. This makes the production-access answers concrete and creates a useful audit trail without adding behavioral analytics to Ritual.

### Current official references

- [Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885)
- [Create and set up an app](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Set up an internal, closed, or open test](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Testing requirements for new Personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Target API level requirements](https://developer.android.com/google/play/requirements/target-sdk)

## Test coverage

Automated tests cover models and persistence choices, daily grouping and summaries, stable calendar highlights, streak calculation/preferences/celebrations, app-lock lifecycle and privacy behavior, dark-mode and stable labels, location models, reminder permission state and planning, custom times, reflection scales, every insight category, ZIP round trips and hostile archives, PDF contents/ranges, CSV escaping and formula safety, and Settings UI.

Sample PDF/CSV files use synthetic entries. Sample PDF color blocks are generated stand-ins; in-app reports load actual meal photos.

## GitHub Actions APK release

Every push to `main` runs `.github/workflows/android-release.yml`. The workflow installs pinned Flutter and Java versions, resolves dependencies, runs analysis and all tests, validates signing secrets, builds a monotonically versioned signed APK, uploads a 90-day workflow artifact, creates a permanent versioned prerelease, and updates the rolling `ritual-latest` prerelease with APK and SHA-256 checksum.

The `ritual-latest` asset is intentionally replaced so one stable URL always downloads the newest APK. Older builds remain attached to their unique versioned GitHub releases instead of disappearing.

Required repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

PKCS12 keystores commonly use one password for the store and private-key entry, but the workflow accepts both fields. Never commit `.jks`, `.keystore`, `key.properties`, passwords, or Base64 key material.

## Versioning

`pubspec.yaml` supplies the human version and local build number. CI overrides the Android build number with a value derived from the workflow run so each published APK can update the previous one. APK updates must use the same signing certificate.

## Wiki source

The Markdown files in `/wiki` are the canonical wiki source. GitHub hosts wikis in a separate `ritual-app.wiki.git` repository. `.github/workflows/publish-wiki.yml` copies these pages there after a push to `main`; the repository's **Wiki** feature must be enabled. Keeping the source in the main repository makes documentation reviewable with code changes.
