#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Compila MediaRemoteAdapter.framework e MediaRemoteAdapterTestClient dai sorgenti in
# Vendor/mediaremote-adapter (BSD-3) e li mette in Resources/MediaRemoteAdapter/ insieme allo script .pl.
# Replica i flag di Vendor/mediaremote-adapter/CMakeLists.txt senza richiedere CMake.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/mediaremote-adapter"
OUT="${1:-$ROOT/Resources/MediaRemoteAdapter}"
NAME="MediaRemoteAdapter"
FW="$OUT/$NAME.framework"
ARCHS=(-arch arm64 -arch x86_64)
MIN="-mmacosx-version-min=11.0"

stamp="$OUT/.built-from"
want="$(cd "$SRC" && find bin include src -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -d' ' -f1)"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ] && [ -x "$FW/Versions/A/$NAME" ] && [ -x "$OUT/${NAME}TestClient" ]; then
  echo "mediaremote-adapter già compilato ($OUT)"
  exit 0
fi

rm -rf "$FW" "$OUT/${NAME}TestClient"
mkdir -p "$FW/Versions/A/Resources" "$FW/Versions/A/Headers"

ADAPTER_SOURCES=(
  src/adapter/env.m src/adapter/get.m src/adapter/globals.m src/adapter/keys.m
  src/adapter/now_playing.m src/adapter/repeat.m src/adapter/seek.m src/adapter/send.m
  src/adapter/shuffle.m src/adapter/speed.m src/adapter/stream.m src/adapter/test.m
  src/private/MediaRemote.m src/utility/Debounce.m src/utility/helpers.m
)

cd "$SRC"
xcrun clang "${ARCHS[@]}" $MIN -dynamiclib -fobjc-arc -fvisibility=default \
  -I include -I src \
  -install_name "@rpath/$NAME.framework/Versions/A/$NAME" \
  -current_version 0.1.0 -compatibility_version 0.1.0 \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  "${ADAPTER_SOURCES[@]}" -o "$FW/Versions/A/$NAME"

cp include/MediaRemoteAdapter.h "$FW/Versions/A/Headers/"
cat > "$FW/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.vandenbe.$NAME</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
</dict></plist>
PLIST
ln -sfn A "$FW/Versions/Current"
ln -sfn Versions/Current/$NAME "$FW/$NAME"
ln -sfn Versions/Current/Headers "$FW/Headers"
ln -sfn Versions/Current/Resources "$FW/Resources"
codesign --force --deep --sign - "$FW"

xcrun clang "${ARCHS[@]}" $MIN -fobjc-arc -I src/test \
  -framework Foundation -framework MediaPlayer \
  src/test/main.m src/test/NowPlayingTest.m -o "$OUT/${NAME}TestClient"
codesign --force --sign - "$OUT/${NAME}TestClient"

cp bin/mediaremote-adapter.pl "$OUT/mediaremote-adapter.pl"
echo "$want" > "$stamp"
echo "mediaremote-adapter compilato in $OUT"
