#!/bin/bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/screenshots.sh [-b|--build] [--dark] [-d|--device <name>]... [-o|--output <dir>]

Launches the app in each App Store screenshot state, a day in San Francisco with the mock
weather, and saves a PNG of each to <dir>/<device>/, `.build/screenshots` by default, emptying
that folder first. Captures on iPhone 18 Pro, iPad Pro 13-inch (M5) (16GB) and Apple Watch
Series 12 (46mm) unless `-d` names others, with the watch app on a watch. An iPhone's or iPad's
status bar shows each state's time, while a watch's clock shows the real time, since simctl
can't override it. `-b` builds first, and `--dark` captures the iPhone and iPad in dark mode,
restoring each simulator's appearance afterward.

Shots keep each simulator's orientation, and an iPad's multitasking mode, which simctl can't
set: rotate it in Simulator, and choose Full Screen Apps in its Settings > Multitasking &
Gestures to hide the window's resize handle.
USAGE
}

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# shellcheck source=lib/screenshots.sh
source "$repo_root/scripts/lib/screenshots.sh"

build_first=0
appearance=light
devices=()
output_dir="$repo_root/.build/screenshots"
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--build)
      build_first=1
      shift
      ;;
    --dark)
      appearance=dark
      shift
      ;;
    -d|--device|-o|--output)
      if [ $# -lt 2 ]; then
        echo "error: $1 needs a value" >&2
        usage >&2
        exit 1
      fi
      case "$1" in
        -d|--device) devices+=("$2") ;;
        *) output_dir=$2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done
if [ ${#devices[@]} -eq 0 ]; then
  devices=("${screenshot_devices[@]}")
fi

products="$repo_root/.build/xcode/Build/Products"
app_path="$products/Debug-iphonesimulator/Chromahora.app"
watch_app_path="$products/Debug-watchsimulator/ChromahoraWatch.app"

# San Francisco on the day the snapshots show, with the mock weather, so every run shows the
# same sky. The app runs in the place's zone, which `-DebugNow` and the days' windows read, so
# the times are San Francisco's whatever the host's zone.
place="37.8N,122.4W"
place_zone="America/Los_Angeles"
day="2026-09-16"

# Each state's file name, numbered in a suggested App Store order, the devices it's for, the
# place's time it shows, and launch arguments after the shared ones. `ios` states run on the
# iPhone and iPad, and `phone` states on the iPhone alone, since the iPad's day panel shows the
# details and the calendar in place of the page and the button.
states=(
  "1-golden-hour|ios|19:05|"
  "2-blue-hour|ios|06:30|"
  "3-details|phone|16:30|-DebugPane details"
  "4-calendar|phone|16:30|-DebugSheet calendar"
  "5-location|ios|16:30|-DebugSheet location"
  "6-night|ios|22:00|"
  "1-countdown|watch|16:30|"
  "2-evening|watch|19:05|-DebugCard evening"
  "3-morning|watch|06:30|-DebugCard morning"
  "4-details|watch|16:30|-DebugCard details"
)

# `build.sh` builds the watch app with the app that embeds it.
if [ "$build_first" -eq 1 ]; then
  ./scripts/build.sh
elif [ ! -d "$app_path" ] || [ ! -d "$watch_app_path" ]; then
  echo "The app isn't built, building first..."
  ./scripts/build.sh
fi

scratch=$(mktemp -d -t chromahora-screenshots.XXXXXX)
# Simulators whose appearance this run changed, as `<udid>=<appearance>`, to put back on exit.
restores=()
# Simulators whose status bar this run overrode, to clear on exit.
status_bars=()
restore() {
  for entry in ${restores[@]+"${restores[@]}"}; do
    xcrun simctl ui "${entry%%=*}" appearance "${entry#*=}" >/dev/null 2>&1 || true
  done
  for udid in ${status_bars[@]+"${status_bars[@]}"}; do
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  done
  rm -rf "$scratch"
}
trap restore EXIT

# Launches `$bundle_id` on simulator `$1` with the place's clock at `$2`, as `HH:MM`, passing the
# rest as launch arguments after the shared ones. `SIMCTL_CHILD_TZ` puts the app in the place's
# zone, and `-DebugPlace` puts the device there without asking for its location.
launch() {
  local udid=$1 time=$2
  shift 2
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  SIMCTL_CHILD_TZ=$place_zone xcrun simctl launch "$udid" "$bundle_id" \
    -DebugPlace "$place" -DebugWeather mock -DebugNow "${day}T$time" "$@" >/dev/null
}

# Sets the status bar clock of simulator `$1` to the place's clock at `$2`, as `HH:MM`. The bar
# reads the time in the host's zone, which the simulator keeps, so it gets the moment the host's
# clock reads the place's time, which also dates an iPad's bar. simctl takes an ISO time only
# with fractional seconds, rejecting a plain time on the hour and showing a plain one as AM on an
# iPad, and drops the date's year when another override comes with it or after it, so this one
# goes alone and last.
override_status_bar_time() {
  local udid=$1 time=$2 seconds
  seconds=$(date -j -f %Y-%m-%dT%H:%M:%S "${day}T$time:00" +%s)
  xcrun simctl status_bar "$udid" override --time "$(date -u -r "$seconds" +%Y-%m-%dT%H:%M:%S.000Z)"
}

# Saves the screen to `$2` once the app on simulator `$1` stops moving: four seconds for it to
# launch, then until two frames a second apart match, so the loading sky's pulse, the debug
# sheet's half-second delay and its slide in are all over. Gives up after twenty seconds. The
# launch screen holds still for its first moments, and its frames match each other, so a
# shorter wait could keep one.
capture_settled() {
  local udid=$1 destination=$2
  local previous="$scratch/previous.png" current="$scratch/current.png"
  sleep 4
  xcrun simctl io "$udid" screenshot "$previous" >/dev/null 2>&1
  for _ in $(seq 1 20); do
    sleep 1
    xcrun simctl io "$udid" screenshot "$current" >/dev/null 2>&1
    if cmp -s "$previous" "$current"; then
      mv "$current" "$destination"
      return
    fi
    mv "$current" "$previous"
  done
  echo "warning: the screen never settled; kept its last frame" >&2
  mv "$previous" "$destination"
}

for device in "${devices[@]}"; do
  # `<udid>\t<runtime>\t<device type>` for the first available simulator with this name or UDID.
  simulator=$(xcrun simctl list devices available --json |
    jq -r --arg device "$device" 'first(.devices | to_entries[] | .key as $runtime | .value[] | select(.name == $device or .udid == $device) | [.udid, $runtime, .deviceTypeIdentifier]) // empty | @tsv')
  if [ -z "$simulator" ]; then
    echo "error: no available simulator named '$device'. Run ./scripts/setup.sh to create it." >&2
    exit 1
  fi
  IFS=$'\t' read -r udid runtime device_type <<<"$simulator"
  case "$runtime:$device_type" in
    *watchOS*) kind=watch ;;
    *iPad*) kind=pad ;;
    *) kind=phone ;;
  esac

  xcrun simctl bootstatus "$udid" -b >/dev/null
  if [ "$kind" = watch ]; then
    bundle_id="com.afollestad.Chromahora.watchkitapp"
    device_app_path=$watch_app_path
  else
    bundle_id="com.afollestad.Chromahora"
    device_app_path=$app_path
    previous_appearance=$(xcrun simctl ui "$udid" appearance)
    if [ "$previous_appearance" != "$appearance" ]; then
      restores+=("$udid=$previous_appearance")
      xcrun simctl ui "$udid" appearance "$appearance"
    fi
    status_bars+=("$udid")
    xcrun simctl status_bar "$udid" override --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  fi
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$device_app_path"
  # A launch to throw away, since the first after an install is the slowest, and could still be
  # blank when the capture starts.
  launch "$udid" 12:00
  capture_settled "$udid" "$scratch/warm-up.png"

  device_dir="$output_dir/$device"
  rm -rf "$device_dir"
  mkdir -p "$device_dir"
  for state in "${states[@]}"; do
    IFS='|' read -r name targets time extra_args <<<"$state"
    case "$targets:$kind" in
      ios:phone|ios:pad|phone:phone|watch:watch) ;;
      *) continue ;;
    esac
    read -r -a launch_args <<<"$extra_args"
    # simctl can't override a watch's status bar, so its clock shows the real time.
    if [ "$kind" != watch ]; then
      override_status_bar_time "$udid" "$time"
    fi
    launch "$udid" "$time" ${launch_args[@]+"${launch_args[@]}"}
    capture_settled "$udid" "$device_dir/$name.png"
    echo "Saved $device_dir/$name.png"
  done
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
done
