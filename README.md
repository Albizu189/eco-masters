# Eco Masters

A complete, touch-first solo ecosystem game for Android, built with **Godot 4.4.1**. Choose a board side, shape landscapes, draft animal habitats, activate a Nature’s Spirit, and turn your final score into solo suns.

## Download

Get **`EcoMasters.apk`** from the repository’s **Releases** section. The automated build updates the `android-latest` release whenever the main branch is rebuilt.

- Android 7.0 (API 24) or newer.
- No login, ads, network connection, or backend.
- The APK is a direct-install, debug-signed build. Android may ask you to allow installation from this source.
- Records, display/sound preferences, and the current saved game stay on the device; uninstalling or clearing app data removes them.

## Included

- Solo market with three groups of three tokens; unselected tokens are discarded at turn end.
- Both 25-space board layouts, six landscape token types, legal stacking, and cube-blocked spaces.
- All 32 Animal cards and 10 Nature’s Spirits, with six rotations, exact habitat heights, score ladders, and special scoring.
- Four-card active limit, one optional draft per turn, and one optional face-up refresh when no card is drafted.
- Side A river scoring, Side B land-area scoring, all other terrain scoring, and solo sun thresholds/configuration bonuses.
- Optional Nature’s Spirit setup: draw two and choose one, or play without a spirit.
- Main menu, illustrated rules, pause/restart, score breakdown, local records, sound toggle, placement pulses, and screen transitions.
- Responsive phone, tablet, portrait, and landscape scaling with touch targets of at least 44 px.
- Light and dark themes, a color-vision-accessible palette, and distinct terrain silhouettes that do not rely on color alone.
- Stacked habitat diagrams with level pips, ring-only cube targets, and an original minimalistic icon for every animal and spirit.
- Current-turn undo for token placement, cubes, drafting, refreshing, market selection, and spirit selection.
- Automatic local saved games, a Continue button, and main-menu navigation from every scene.
- Habitat patterns on available and acquired cards, owned-card paging, live card points, and a live cumulative score breakdown.

All visual components and sounds are original Eco Masters assets. Protected publisher art and rulebook files are not redistributed. See `CREDITS.md` and `docs/REFERENCES.md`.

## Why Godot instead of Unity

Godot 4 is open source, lightweight, and well suited to a data-driven 2D board game. It keeps the complete project editable without a proprietary engine license or a large Unity toolchain. The Android package uses the official Godot Android library from Maven Central, so building does **not** require downloading the all-platform export-template archive.

## Project layout

```text
project.godot                 Godot project
scenes/main.tscn              Application entry scene
scripts/rules.gd             Cards, placement, habitat matching, scoring
scripts/game_state.gd        Turns, undo, saves, decks, scoring, end conditions
scripts/art.gd               Original accessible vector component renderer
scripts/main.gd              Responsive UI, themes, input, audio, records, motion
assets/                      Original vector application icon
tests/                       Rules, UI, and rendered-capture checks
android/                     Native Android host using GodotActivity
scripts/build-android.sh     Reproducible local APK build
.github/workflows/android.yml Tests, APK artifact, and release automation
```

## Build the APK

Prerequisites:

1. JDK 17.
2. Godot **4.4.1 stable** on `PATH`, or set `GODOT_BIN` to its executable.
3. Gradle **8.9** on `PATH`, or set `GRADLE_BIN`.
4. Android SDK with `platform-tools`, `platforms;android-34`, and `build-tools;34.0.0`.
5. Set `ANDROID_HOME` to the SDK directory.

Then run:

```bash
bash scripts/build-android.sh
```

The installable APK is written to `build/EcoMasters.apk`. The build exports `main.pck`, compiles the native Android host, and copies the signed debug APK. For production distribution, configure your own protected release signing key in `android/app/build.gradle`; never commit private signing credentials.

## Test

Import once, then run the deterministic rules suite:

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_rules.gd
```

The suite performs **323 checks**, including every card pattern in all six rotations, stack rules, terrain and card scoring, sun conversion, market refresh, undo boundaries, JSON save/load, saved undo history, RNG continuation, and live card points.

`tests/test_ui.gd` performs **118 interaction and layout checks per resolution**, using the real screen hit regions in a running Godot window. It covers dark mode, undo, save/continue, live scoring, card paging, navigation, touch-target sizes, and on-screen controls. Version 1.1 was verified at 375×812, 390×844, 430×932, 844×390, 1024×768, 1280×800, 1600×2560, and 1920×1200; 2560×1600 was also visually capture-tested.

`tests/capture.gd` renders home, gameplay, and results screenshots at the current window resolution. Add `-- --dark` after the script arguments to capture the dark theme.

## Game data notes

Token and card definitions are data, not UI exceptions. Patterns use axial hex coordinates and may rotate but not mirror. A token can participate in multiple habitats. Animal cubes permanently occupy their target spaces even if a later legal stack changes the surrounding landscape.

This is an unofficial independent project inspired by the solo mechanics of Harmonies; it is not affiliated with or endorsed by Libellud.

