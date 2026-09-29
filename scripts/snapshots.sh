#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

usage() {
  cat <<'USAGE'
Usage: ./scripts/snapshots.sh [--no-xcsift] <verify|record> [test_identifier ...]

Each suite runs on its own device: `ChromahoraTests/SnapshotTests` on iPhone 18 Pro, and
`ChromahoraTests/WideSnapshotTests` on iPad mini (A17 Pro). Defaults to both suites when no
test identifiers are provided.
Failed comparisons write the new image to `.build/snapshot-failures` (override with SNAPSHOT_ARTIFACTS).

Examples:
  ./scripts/snapshots.sh verify
  ./scripts/snapshots.sh verify 'ChromahoraTests/SnapshotTests/afternoon()'
  ./scripts/snapshots.sh record
  ./scripts/snapshots.sh record 'ChromahoraTests/WideSnapshotTests/afternoon()'
USAGE
}

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

use_xcsift=true
if [ "${1:-}" = "--no-xcsift" ]; then
  use_xcsift=false
  shift
fi

if [ "$#" -lt 1 ]; then
  usage >&2
  exit 1
fi

mode=$1
shift

case "$mode" in
  verify|record)
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

# shellcheck source=lib/testing.sh
source "$repo_root/scripts/lib/testing.sh"

if [ "$#" -eq 0 ]; then
  set -- "${snapshot_suites[@]}"
fi

# Sorted by suite, since each suite runs on its own device rather than SIMULATOR's.
phone_tests=()
wide_tests=()
for test_name in "$@"; do
  case "$(snapshot_device "$test_name")" in
    "$snapshot_phone_device")
      phone_tests+=("-only-testing:$test_name")
      ;;
    "$snapshot_wide_device")
      wide_tests+=("-only-testing:$test_name")
      ;;
    *)
      echo "error: $test_name isn't in ChromahoraTests/SnapshotTests or ChromahoraTests/WideSnapshotTests." >&2
      exit 1
      ;;
  esac
done

prepare_snapshot_artifacts

raw_log=$(mktemp -t chromahora-snapshots.XXXXXX)
trap 'rm -f "$raw_log"' EXIT

# Keeps the raw log alongside the xcsift summary, since only the raw log names each test's
# outcome. Returns xcodebuild's status without touching `set -e`, which `record` turns off.
run_and_format() {
  local status=0
  if [ "$use_xcsift" = true ] && command -v xcsift >/dev/null 2>&1; then
    "$@" 2>&1 | tee "$raw_log" | xcsift -f toon -w || status=${PIPESTATUS[0]}
  else
    "$@" 2>&1 | tee "$raw_log" || status=${PIPESTATUS[0]}
  fi
  return "$status"
}

# Runs the `-only-testing` flags after the device on it. Time labels format with the process
# locale, so tests launch in the one the baselines use. Parallel testing boots slow simulator
# clones, and failure diagnostics take a sysdiagnose that stalls every failing run for about
# ten minutes.
run_snapshot_tests() {
  local device=$1
  shift
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
}

run_verify() {
  export TEST_RUNNER_SNAPSHOT_TESTING_RECORD=missing
  if [ "${#phone_tests[@]}" -gt 0 ]; then
    run_snapshot_tests "$snapshot_phone_device" "${phone_tests[@]}"
    require_every_test_ran "$raw_log"
  fi
  if [ "${#wide_tests[@]}" -gt 0 ]; then
    run_snapshot_tests "$snapshot_wide_device" "${wide_tests[@]}"
    require_every_test_ran "$raw_log"
  fi
}

if [ "$mode" = "verify" ]; then
  run_verify
  echo "Snapshot verification passed."
  exit 0
fi

# SnapshotTesting fails every test it records, by design, so a non-zero status here says
# nothing about whether the baselines are good. Swallow it and let the verify pass below
# be the judge, which is what makes `record` safe to trust as a single command.
export TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all
set +e
record_status=0
if [ "${#phone_tests[@]}" -gt 0 ]; then
  run_snapshot_tests "$snapshot_phone_device" "${phone_tests[@]}" || record_status=$?
fi
if [ "${#wide_tests[@]}" -gt 0 ]; then
  run_snapshot_tests "$snapshot_wide_device" "${wide_tests[@]}" || record_status=$?
fi
set -e

if [ "$record_status" -ne 0 ]; then
  echo "Snapshot record run exited $record_status; verifying recorded references..."
fi

run_verify
echo "Snapshots recorded and verified."
