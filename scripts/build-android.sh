#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
GRADLE_BIN="${GRADLE_BIN:-gradle}"
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"

if [[ -z "$ANDROID_HOME" ]]; then
  echo "Set ANDROID_HOME to your Android SDK directory." >&2
  exit 1
fi
printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$ROOT/android/local.properties"

"$GODOT_BIN" --headless --path "$ROOT" --editor --import --quit
"$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_rules.gd
mkdir -p "$ROOT/android/app/src/main/assets" "$ROOT/build"
"$GODOT_BIN" --headless --path "$ROOT" --export-pack Android "$ROOT/android/app/src/main/assets/main.pck"
"$GRADLE_BIN" -p "$ROOT/android" assembleDebug
cp "$ROOT/android/app/build/outputs/apk/debug/app-debug.apk" "$ROOT/build/EcoMasters.apk"
echo "Built $ROOT/build/EcoMasters.apk"
