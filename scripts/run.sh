#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

build_first=0
watch=0
# Everything after `--` goes to the app as launch arguments, such as the debug drawer's
# `-DebugNow 2026-09-16T03:00:00`.
launch_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--build)
      build_first=1
      shift
      ;;
    -w|--watch)
      watch=1
      shift
      ;;
    --)
      shift
      launch_args=("$@")
      break
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "usage: $0 [-b|--build] [-w|--watch] [-- <launch arguments>]" >&2
      exit 1
      ;;
  esac
done

# The watch app runs on a watch simulator of its own, which needs no paired phone, since it
# fetches its own sun times. `WATCH_SIMULATOR` picks another watch, as `SIMULATOR` does a phone.
if [ "$watch" -eq 1 ]; then
  bundle_id="com.afollestad.Chromahora.watchkitapp"
  app_path="$repo_root/.build/xcode/Build/Products/Debug-watchsimulator/ChromahoraWatch.app"
  simulator_name=${WATCH_SIMULATOR:-"Apple Watch Series 12 (46mm)"}
  simulator_variable=WATCH_SIMULATOR
  build_args=(--watch)
else
  bundle_id="com.afollestad.Chromahora"
  app_path="$repo_root/.build/xcode/Build/Products/Debug-iphonesimulator/Chromahora.app"
  simulator_name=${SIMULATOR:-"iPhone 18 Pro"}
  simulator_variable=SIMULATOR
  build_args=()
fi

udid=$(xcrun simctl list devices available | grep -F "    $simulator_name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
if [ -z "$udid" ]; then
  echo "error: no available simulator named '$simulator_name'. Set $simulator_variable to another device name." >&2
  exit 1
fi

if [ "$build_first" -eq 1 ]; then
  ./scripts/build.sh ${build_args[@]+"${build_args[@]}"}
elif [ ! -d "$app_path" ]; then
  echo "$(basename "$app_path") not found, building first..."
  ./scripts/build.sh ${build_args[@]+"${build_args[@]}"}
fi

xcrun simctl bootstatus "$udid" -b >/dev/null
open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$udid" 2>/dev/null || true

xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app_path"
# macOS ships bash 3.2, where `set -u` treats an empty array as unbound, so expand it only when set.
xcrun simctl launch "$udid" "$bundle_id" ${launch_args[@]+"${launch_args[@]}"}

echo "Launched $bundle_id on $simulator_name ($udid)."
