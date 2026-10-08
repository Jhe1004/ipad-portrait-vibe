#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
build_dir="${1:-$project_dir/build}"
dist_dir="${2:-$project_dir/dist}"
app="$build_dir/iPad Portrait Vibe.app"
[[ -d "$app" ]] || { printf '%s\n' 'Build the app first with bash build.sh.' >&2; exit 1; }
mkdir -p "$dist_dir"
version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
archive="$dist_dir/iPad-Portrait-Vibe-v$version-macos-universal.zip"
/usr/bin/ditto -c -k --keepParent --norsrc "$app" "$archive"
(cd "$dist_dir" && /usr/bin/shasum -a 256 "$(basename "$archive")" > SHA256SUMS.txt)
printf '%s\n' "$archive"
