#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
build_dir="${1:-$project_dir/build}"
mkdir -p "$build_dir"
build_dir="$(cd "$build_dir" && pwd)"
app="$build_dir/VibeScreen.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build_dir/01_objects"
read -r -a build_archs <<< "${IPV_ARCHS:-arm64 x86_64}"
objects=()
for arch in "${build_archs[@]}"; do
  /usr/bin/xcrun clang -arch "$arch" -fobjc-arc -O2 \
    -Wall -Wextra -Wno-unused-parameter -Wno-incompatible-pointer-types \
    -mmacosx-version-min=14.0 -framework Cocoa -framework CoreGraphics \
    "$project_dir/src/main.m" -o "$build_dir/01_objects/VibeScreen-$arch"
  objects+=("$build_dir/01_objects/VibeScreen-$arch")
done
/usr/bin/xcrun lipo -create "${objects[@]}" -output "$app/Contents/MacOS/VibeScreen"
/usr/bin/xcrun clang -fobjc-arc -framework Cocoa "$project_dir/tools/icon.m" -o "$build_dir/01_objects/icon-maker"
"$build_dir/01_objects/icon-maker" "$build_dir/01_objects/AppIcon.iconset"
/usr/bin/iconutil -c icns "$build_dir/01_objects/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
/bin/cp "$project_dir/Info.plist" "$app/Contents/Info.plist"
sign_identity="${IPV_SIGN_IDENTITY:--}"
sign_options=(--force --sign "$sign_identity")
if [[ "$sign_identity" != "-" ]]; then sign_options+=(--options runtime --timestamp); fi
/usr/bin/codesign "${sign_options[@]}" "$app"
/usr/bin/codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
