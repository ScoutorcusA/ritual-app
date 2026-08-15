# Official Ritual Builds

Ritual's source code may be inspected, modified, built, and distributed under the Mozilla Public License 2.0. An open-source license does not, however, make every resulting package an official Ritual release.

Only an Android package that meets **all** of these conditions may be described as an **official Ritual build**:

1. It is published by the Ritual maintainer through this repository's [GitHub Releases](https://github.com/ScoutorcusA/ritual-app/releases).
2. It is produced by the repository's release workflow from the stated source revision.
3. It is signed with the private Ritual Android release key controlled by the maintainer.

The same principle will apply to any future iOS release: it must be published through the maintainer's authorized distribution account and signed with the maintainer-controlled release identity.

Self-built packages, fork builds, pull-request artifacts, debug builds, and third-party redistributions are **unofficial**. They must not imply affiliation or endorsement and must follow the renaming requirements in [TRADEMARKS.md](TRADEMARKS.md).

## Verifying an Android download

- Download from this repository's Releases page, not an unknown mirror.
- Compare the APK's SHA-256 digest with the adjacent `.sha256` file.
- Android's signing certificate establishes whether an installed official build can be updated by a later official build. A checksum alone does not prove who signed an APK.

The private signing key and its passwords must never be committed, posted in an issue, included in an archive, or shared with contributors. Losing the key would break the trusted update path for existing installations.

The rolling `ritual-latest` release points to the newest official development build. Permanent versioned releases preserve older official builds rather than replacing them.
