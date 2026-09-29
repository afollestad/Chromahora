#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# shellcheck source=lib/testing.sh
source "$repo_root/scripts/lib/testing.sh"
prepare_snapshot_artifacts

simulator_name=${SIMULATOR:-$snapshot_phone_device}

raw_log=$(mktemp -t chromahora-test.XXXXXX)
trap 'rm -f "$raw_log"' EXIT

# Keeps the raw log alongside the xcsift summary, since only the raw log names each test's outcome.
run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    "$@" 2>&1 | tee "$raw_log" | xcsift -f toon -w
  else
    "$@" 2>&1 | tee "$raw_log"
  fi
}

if [ "$#" -eq 0 ]; then
  set -- ChromahoraTests
fi

# Snapshot tests run on their suite's device and everything else on SIMULATOR's, one pass per
# device. The whole bundle sends each snapshot suite to its own device, so the default run
# covers both, and SIMULATOR's pass skips the suites that belong elsewhere.
elsewhere_suites=()
simulator_skips=()
for suite in "${snapshot_suites[@]}"; do
  if [ "$(snapshot_device "$suite")" != "$simulator_name" ]; then
    elsewhere_suites+=("$suite")
    simulator_skips+=("-skip-testing:$suite")
  fi
done
simulator_tests=()
phone_tests=()
wide_tests=()
for test_name in "$@"; do
  targets=("$test_name")
  if [ "$test_name" = ChromahoraTests ]; then
    targets+=(${elsewhere_suites[@]+"${elsewhere_suites[@]}"})
  fi
  for target in "${targets[@]}"; do
    device=$(snapshot_device "$target")
    if [ -z "$device" ] || [ "$device" = "$simulator_name" ]; then
      simulator_tests+=("-only-testing:$target")
    elif [ "$device" = "$snapshot_phone_device" ]; then
      phone_tests+=("-only-testing:$target")
    else
      wide_tests+=("-only-testing:$target")
    fi
  done
done

# Parallel testing runs on simulator clones, which boot slowly and shut the original down.
# Failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.
run_tests() {
  local device=$1
  shift
  echo "Testing on $device..."
  run_and_format xcodebuild \
    -project Chromahora.xcodeproj \
    -scheme Chromahora \
    -destination "platform=iOS Simulator,name=$device" \
    -derivedDataPath .build/xcode \
    -testLanguage en \
    -testRegion US \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "$@" \
    test
  require_every_test_ran "$raw_log"
}

# macOS ships bash 3.2, where `set -u` treats an empty array as unbound, so expand it only when set.
if [ "${#simulator_tests[@]}" -gt 0 ]; then
  run_tests "$simulator_name" "${simulator_tests[@]}" ${simulator_skips[@]+"${simulator_skips[@]}"}
fi
if [ "${#phone_tests[@]}" -gt 0 ]; then
  run_tests "$snapshot_phone_device" "${phone_tests[@]}"
fi
if [ "${#wide_tests[@]}" -gt 0 ]; then
  run_tests "$snapshot_wide_device" "${wide_tests[@]}"
fi
echo "Tests passed."
