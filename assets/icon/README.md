# Launcher Icon Assets

## Required files

Place two PNG files in this directory before running `flutter pub run flutter_launcher_icons`:

### `app_icon.png`
- Size: **1024×1024 px** (minimum), square
- Used as the full icon on iOS and as the legacy Android icon
- Design: Piano keys on a dark `#0A0500` background with gold (`#D4A84B`) accents
- Must have a transparent or dark background (no white margins)

### `app_icon_foreground.png`
- Size: **1024×1024 px**, square
- Used as the foreground layer for Android adaptive icons (API 26+)
- Keep the actual artwork centered in the inner **66%** of the canvas (safe zone)
- Background is supplied separately as `#0A0500` in `flutter_icons.yaml`

## Generating icons

Once the PNG files are in place:

```bash
flutter pub get
flutter pub run flutter_launcher_icons -f flutter_icons.yaml
```

## Suggested design
A minimal gold piano silhouette — three white keys and two black keys — centred
on the dark background. Export from Figma, Illustrator, or any vector tool at
1024×1024 px as a lossless PNG.
