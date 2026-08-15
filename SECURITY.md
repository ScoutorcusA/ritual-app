# Security Policy

Ritual stores sensitive journal information and photos locally, so security and privacy reports are taken seriously.

## Supported versions

| Version | Security updates |
| --- | --- |
| Latest versioned GitHub release | Yes |
| Rolling `ritual-latest` development release | Yes |
| Older builds and unofficial forks | No |

## Report a vulnerability privately

Use GitHub's [private vulnerability reporting form](https://github.com/ScoutorcusA/ritual-app/security/advisories/new). If that form is unavailable, open a minimal public issue asking for a private contact channel. Do **not** put vulnerability details, exploit steps, or private user data in a public issue.

Include, where safe:

- The affected version and platform
- A concise description of the impact
- Reproduction steps using synthetic data
- Any suggested mitigation

Never send a real journal archive, meal photo, reflection, precise location, PIN, keystore, signing password, token, or other credential. The maintainer will acknowledge reports as soon as practical, attempt to reproduce them, and coordinate remediation and disclosure according to severity.

## Relevant security areas

Reports are especially useful for problems involving:

- App-private journal or photo storage
- App-lock authentication and data exposure
- ZIP import validation, archive traversal, or malicious files
- Exported PDF, CSV, or ZIP content
- Android permissions or unintended network transmission
- Dependency and website supply-chain risks
- Release automation, APK integrity, or signing identity

General feature requests, device-specific support questions, and vulnerabilities that only affect unofficial modified builds should use the normal issue forms.

See [OFFICIAL_BUILDS.md](OFFICIAL_BUILDS.md) for the official release and signing policy.
