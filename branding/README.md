# GameLog app icon: "Face buttons"

Four glossy controller face buttons (green, red, blue, amber) in a diamond on a
dark navy tile.

## Colours

| Part        | Light → dark            |
|-------------|-------------------------|
| Background  | `#232741` → `#0D0F19`   |
| Top (green) | `#34D399` → `#059669`   |
| Right (red) | `#F87171` → `#DC2626`   |
| Bottom (blue) | `#60A5FA` → `#2563EB` |
| Left (amber)| `#FBBF24` → `#D97706`   |

## Files

- `svg/full.svg` – complete icon (108×108 adaptive canvas)
- `svg/background.svg`, `svg/foreground.svg`, `svg/monochrome.svg` – Android adaptive layers
  (the glyph stays inside the 66dp safe zone)
- `play-store-512.png` – Play Store listing icon
- `make_icon_svgs.py` – script that generated the SVGs (concept `buttons`)

The PNGs in `android/app/src/main/res/mipmap-*` and `web/` were rendered from these SVGs.
