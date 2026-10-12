# GameLogs app icon — "Rated cartridge"

A dark game cartridge whose label carries a rating star, on a lime tile.

## Brand colors

| Token  | Hex       | Use                                 |
|--------|-----------|-------------------------------------|
| Lime   | `#C8F031` | Icon background, primary accent     |
| Ink    | `#0E0F14` | Cartridge body, star                |
| Cream  | `#F2F1EC` | Cartridge label                     |
| Slate  | `#181A22` | Dark-mode tile                      |

## Files

```
svg/                         Source vectors (edit these, re-export PNGs from them)
  gamelogs-icon-square.svg     Full-bleed square (stores)
  gamelogs-icon-rounded.svg    Rounded tile (marketing, web)
  gamelogs-icon-rounded-dark.svg
  gamelogs-mark.svg            Cartridge only, transparent (splash screens, in-app logo)
  gamelogs-mark-mono.svg       One-color cartridge
  android-adaptive-*.svg       Adaptive icon layers on the 108dp canvas

ios/
  AppIcon-1024.png             Square, opaque — iOS applies the corner mask itself
  AppIcon-1024-dark.png        iOS 18+ dark appearance (transparent background)
  AppIcon-1024-tinted.png      iOS 18+ tinted appearance (white glyph, transparent)

android/
  mipmap-{mdpi…xxxhdpi}/       ic_launcher, ic_launcher_round,
                               ic_launcher_foreground, ic_launcher_monochrome
  mipmap-anydpi-v26/           Adaptive icon XML (background + foreground + monochrome)
  values/ic_launcher_background.xml   Background color resource
  play-store-512.png           Google Play listing icon

web/
  favicon.svg, favicon-32.png, apple-touch-icon-180.png,
  icon-192.png, icon-512.png, icon-maskable-512.png
```

Grip ridges on the cartridge are dropped at 48px and below so the star stays legible.

## Wiring it in

**Expo (app.json / app.config):**
```json
{
  "expo": {
    "icon": "./assets/icon/ios/AppIcon-1024.png",
    "ios": {
      "icon": {
        "light": "./assets/icon/ios/AppIcon-1024.png",
        "dark": "./assets/icon/ios/AppIcon-1024-dark.png",
        "tinted": "./assets/icon/ios/AppIcon-1024-tinted.png"
      }
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/icon/android/mipmap-xxxhdpi/ic_launcher_foreground.png",
        "monochromeImage": "./assets/icon/android/mipmap-xxxhdpi/ic_launcher_monochrome.png",
        "backgroundColor": "#C8F031"
      }
    },
    "web": { "favicon": "./assets/icon/web/favicon-32.png" }
  }
}
```

**Bare React Native / native Android:** copy `android/mipmap-*` and `android/values/ic_launcher_background.xml` into `android/app/src/main/res/` (merge, don't overwrite other values files).

**Native iOS / bare RN:** in Xcode, open `Assets.xcassets › AppIcon`, set it to "Single Size", and drop in the three 1024 PNGs for Any / Dark / Tinted.

**Flutter:** use `flutter_launcher_icons` with `image_path: ios/AppIcon-1024.png`, `adaptive_icon_background: "#C8F031"`, `adaptive_icon_foreground: android/mipmap-xxxhdpi/ic_launcher_foreground.png`, `adaptive_icon_monochrome: android/mipmap-xxxhdpi/ic_launcher_monochrome.png`.

**Web / PWA:** reference `web/icon-192.png`, `web/icon-512.png` and `web/icon-maskable-512.png` (`"purpose": "maskable"`) in the manifest; `apple-touch-icon-180.png` as the apple-touch-icon.
