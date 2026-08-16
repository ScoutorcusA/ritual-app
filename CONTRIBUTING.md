# Contributing to Ritual

Thank you for helping make Ritual more useful, private, and welcoming. Contributions can include bug reports, documentation, accessibility improvements, translations, tests, design discussion, and code.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Please report security problems through [SECURITY.md](SECURITY.md), not a public issue.

## Before opening an issue

- Search existing issues to avoid duplicates.
- Use the appropriate issue form and provide a small, reproducible example.
- Use synthetic entries, generated images, and redacted logs.
- Never upload a real journal export, meal photo, reflection, precise location, PIN, signing key, password, token, or other private information.

The public [roadmap](ROADMAP.md) describes the project's current direction, but thoughtful proposals outside it are welcome.

## Project principles

Changes should preserve Ritual's core promises:

- The app is free forever, with no feature paywall for non-supporters.
- Journal data stays on the device unless the person explicitly exports it.
- Ritual has no ads, behavioral analytics, account requirement, or default cloud service.
- The experience is nonjudgmental: no calorie counting, diet scoring, or medical claims.
- Accessibility, understandable language, and reliable data export matter.

Discuss a change before implementing it if it would add a network service, SDK, account, analytics, advertising, cloud sync, new sensitive permission, or major product behavior.

## Local development

Install a current Flutter SDK and Android development environment, then run:

```sh
flutter pub get
flutter run
```

Before submitting a pull request, run:

```sh
flutter analyze
flutter test
dart run tool/localization_tool.dart check
```

Volunteer translators can add a locale without changing app screens or website pages. Follow the [translation guide](wiki/Translations-and-Languages.md), edit the canonical files in `translations/`, and preserve every `{placeholder}` exactly.

Do not use a release keystore for local development. A debug-signed local APK is an unofficial build and cannot update an installation signed with Ritual's private release key.

## Pull requests

1. Keep each pull request focused on one concern.
2. Link the relevant issue, or explain the user problem directly for a small change.
3. Add or update tests for behavior changes.
4. Update the README, wiki, privacy disclosures, and roadmap when the user-facing behavior changes.
5. Include screenshots for visual work, using synthetic content only.
6. Complete the privacy and testing checklist in the pull-request template.

Maintainers may ask for changes or decline work that conflicts with the project's privacy model, tone, or current capacity. A merged contribution does not guarantee that a feature will appear in the next release.

## Licensing and brand

By submitting a contribution, you agree to license it under the [Mozilla Public License 2.0](LICENSE) and represent that you have the right to do so. No contributor license agreement is currently required.

The license covers source code, not the Ritual name, logo, visual identity, or official-build status. Forks and redistributions must follow [TRADEMARKS.md](TRADEMARKS.md) and [OFFICIAL_BUILDS.md](OFFICIAL_BUILDS.md). Release credentials remain solely with the maintainer.
