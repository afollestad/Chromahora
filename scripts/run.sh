#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

usage="usage: $0 [-b|--build] [-w|--watch] [-s|--simulator] [-d|--device <name or UDID>] [-- <launch arguments>]"
build_first=0
watch=0
# A reachable iPhone or iPad runs the app ahead of the simulator, unless `-s` or a set `SIMULATOR`
# asks for the simulator.
simulator_only=0
if [ -n "${SIMULATOR:-}" ]; then
  simulator_only=1
fi
# `-d` picks a device or simulator by name or UDID.
requested_device=""
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
    -s|--simulator)
      simulator_only=1
      shift
      ;;
    -d|--device)
      if [ $# -lt 2 ]; then
        echo "error: $1 needs a device name or UDID" >&2
        echo "$usage" >&2
        exit 1
      fi
      requested_device=$2
      shift 2
      ;;
    --)
      shift
      launch_args=("$@")
      break
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "$usage" >&2
      exit 1
      ;;
  esac
done

# The watch app runs on a watch simulator of its own, which needs no paired phone, since it
# fetches its own sun times. `WATCH_SIMULATOR` picks another watch, as `SIMULATOR` does a phone.
if [ "$watch" -eq 1 ]; then
  bundle_id="com.afollestad.Chromahora.watchkitapp"
  default_simulator=${WATCH_SIMULATOR:-"Apple Watch Series 12 (46mm)"}
  simulator_variable=WATCH_SIMULATOR
  simulator_only=1
else
  bundle_id="com.afollestad.Chromahora"
  default_simulator=${SIMULATOR:-"iPhone 18 Pro"}
  simulator_variable=SIMULATOR
fi

# Prints `<udid>\t<name>` for each paired iPhone and iPad that devicectl can reach now, over USB or
# the network. Its State column reads "available (paired)" for one it can reach, and "connected"
# while a tunnel to it is open.
physical_devices() {
  xcrun devicectl list devices \
    --filter "Reality = 'physical' AND Platform = 'iOS' AND properties.connection.pairingState = 'paired' AND (State BEGINSWITH 'available' OR State = 'connected')" \
    --json-output - --omit-deprecated-fields-in-json --quiet --timeout 10 2>/dev/null |
    jq -r '.result.devices[] | select(.properties.hardware.udid) | [.properties.hardware.udid, .properties.state.name] | @tsv' || true
}

# Prints `<udid>\t<name>` for the first available simulator with this name or UDID.
simulator() {
  xcrun simctl list devices available --json |
    jq -r --arg device "$1" 'first(.devices[][] | select(.name == $device or .udid == $device)) | [.udid, .name] | @tsv'
}

udid=""
name=""
physical=0
if [ "$simulator_only" -eq 0 ]; then
  while IFS=$'\t' read -r device_udid device_name; do
    if [ -z "$requested_device" ] || [ "$requested_device" = "$device_udid" ] || [ "$requested_device" = "$device_name" ]; then
      udid=$device_udid
      name=$device_name
      physical=1
      break
    fi
  done < <(physical_devices)
fi
if [ -z "$udid" ]; then
  simulator_name=${requested_device:-$default_simulator}
  IFS=$'\t' read -r udid name < <(simulator "$simulator_name") || true
  if [ -z "$udid" ]; then
    if [ -n "$requested_device" ]; then
      echo "error: no reachable device or available simulator named '$requested_device'. List them with 'xcrun devicectl list devices'." >&2
    else
      echo "error: no available simulator named '$simulator_name'. Set $simulator_variable to another device name." >&2
    fi
    exit 1
  fi
fi

if [ "$watch" -eq 1 ]; then
  app_path="$repo_root/.build/xcode/Build/Products/Debug-watchsimulator/ChromahoraWatch.app"
  build_args=(--watch)
elif [ "$physical" -eq 1 ]; then
  app_path="$repo_root/.build/xcode/Build/Products/Debug-iphoneos/Chromahora.app"
  build_args=(--device "$udid")
else
  app_path="$repo_root/.build/xcode/Build/Products/Debug-iphonesimulator/Chromahora.app"
  build_args=()
fi

# macOS ships bash 3.2, where `set -u` treats an empty array as unbound, so expand it only when set.
if [ "$build_first" -eq 1 ]; then
  ./scripts/build.sh ${build_args[@]+"${build_args[@]}"}
elif [ ! -d "$app_path" ]; then
  echo "$(basename "$app_path") not found, building first..."
  ./scripts/build.sh ${build_args[@]+"${build_args[@]}"}
fi

if [ "$physical" -eq 1 ]; then
  xcrun devicectl device install app --device "$udid" --quiet "$app_path"
  # `--` keeps devicectl from reading launch arguments such as `-DebugNow` as its own options.
  xcrun devicectl device process launch --device "$udid" --terminate-existing --quiet -- "$bundle_id" ${launch_args[@]+"${launch_args[@]}"}
else
  xcrun simctl bootstatus "$udid" -b >/dev/null
  open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$udid" 2>/dev/null || true

  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"
  xcrun simctl launch "$udid" "$bundle_id" ${launch_args[@]+"${launch_args[@]}"}
fi

echo "Launched $bundle_id on $name ($udid)."
