# Ritual brand assets

`ritual-logo.svg` is the authoritative full-background app icon. `ritual-logo-foreground.svg` is the transparent foreground used by Android adaptive icons. The generated monochrome PNG supplies Android 13+ themed icons. All variants use the same 1024-unit geometry.

## Palette

- Warm cream: `#F6F1E7`
- Deep charcoal: `#1E2A2D`
- Soft sage: `#71826B`

## Regenerating exports

Run:

```sh
python3 tool/generate_brand_assets.py
dart run flutter_launcher_icons
```

The first command creates the PNG masters, high-resolution exports, complete future iOS `AppIcon.appiconset`, and website icons. The Flutter command regenerates Android legacy and adaptive launcher resources from those masters.

Do not add text, a status dot, gradients, shadows, or photographic detail to the primary mark. The camera corners, bowl, and steam should remain readable at small sizes.

The Ritual name, logo, icon, and visual identity are governed by [`TRADEMARKS.md`](../../TRADEMARKS.md), not the MPL 2.0 source-code license.
