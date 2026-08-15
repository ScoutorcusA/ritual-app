# Export and Import

Full journal ZIPs offer two choices: a recommended password-protected AES-256 ZIP or a standard unencrypted ZIP. PDF and CSV reports remain unencrypted for broad compatibility. Store every exported file privately and share only with trusted recipients. Ritual does not store or recover export passwords.

## Full journal ZIP

The ZIP is intended for backup and restoration. It contains `ritual-export.json` plus original photo bytes under `photos/`. Manifest schema version 1 records meal type, feelings, note, UTC timestamp, optional coordinates/place, optional 1–5 reflection values, photo path, photo SHA-256, and an entry fingerprint.

Export fails as one operation if a photo is missing or exceeds safety limits. Current limits are 10,000 entries, 32 MiB per photo, 512 MiB total archive content, and a 10 MiB manifest.

Production export hashes each source photo as a stream, writes a disk-backed temporary ZIP one photo at a time, and streams that file into Android's user-selected destination. It does not retain every photo and the completed ZIP in memory together. Encrypted ZIP processing is still bounded by one photo at a time because each ZIP member is encrypted independently. ZIP creation, encryption, decryption, and verification run in a background worker so they do not block Flutter's interface thread.

## ZIP import validation

Encrypted ZIPs prompt for the export password before verification. Before database insertion Ritual verifies ZIP structure, duplicate filenames, traversal/absolute paths, symbolic links, uncompressed size, manifest presence/version/count, field types and lengths, coordinate ranges, scale ranges, every photo SHA-256, and every entry fingerprint. Photos are streamed into a temporary staging directory one at a time, prepared first, and database inserts use a transaction. Failed or canceled imports clean up staged files. A unique stored fingerprint skips exact duplicates on repeat imports.

Import retains original entry dates but deliberately does not trigger the first-entry streak overlay. Imported entries do affect journal groups, summaries, insights, and calculated streak values after import.

## PDF report

The PDF is designed for personal review with a dietitian/doctor. Its compact day headings, smaller photo thumbnails, and reduced card spacing place substantially more entries on each page while preserving every recorded field. It groups selected entries by day and includes real meal photos, meal types, times, feelings, notes, place/coordinates, and enabled values that were recorded. Solid-color photos appear only in repository sample reports because the generator uses synthetic test images.

## CSV report

CSV contains one entry per row and all non-photo journal fields. It omits photos and internal image paths. Fields containing commas, quotes, or line breaks are correctly quoted. User-authored text beginning with spreadsheet formula characters is neutralized to reduce formula injection when opened in spreadsheet software.

## Date ranges

PDF and CSV offer Last 7 days, Last 30 days, and a custom inclusive start/end date. The selection dialog shows the exact number of matching entries before export. Boundaries use local calendar days, then entries are output chronologically.
