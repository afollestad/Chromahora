#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

bundle_id="com.afollestad.Chromahora"
app_path="$repo_root/.build/xcode/Build/Products/Debug-iphonesimulator/Chromahora.app"
simulator_name=${SIMULATOR:-"iPhone 18 Pro"}

build_first=0
for arg in "$@"; do
  case "$arg" in
    -b|--build)
      build_first=1
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      echo "usage: $0 [-b|--build]" >&2
      exit 1
      ;;
  esac
done

udid=$(xcrun simctl list devices available | grep -F "    $simulator_name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
if [ -z "$udid" ]; then
  echo "error: no available simulator named '$simulator_name'. Set SIMULATOR to another device name." >&2
  exit 1
fi

if [ "$build_first" -eq 1 ]; then
  ./scripts/build.sh
elif [ ! -d "$app_path" ]; then
  echo "Chromahora.app not found, building first..."
  ./scripts/build.sh
fi

xcrun simctl bootstatus "$udid" -b >/dev/null
open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$udid" 2>/dev/null || true

xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch "$udid" "$bundle_id"

echo "Launched $bundle_id on $simulator_name ($udid)."
