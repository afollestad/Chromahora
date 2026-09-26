#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

usage() {
  cat <<'USAGE'
Usage: ./scripts/snapshots.sh [--no-xcsift] <verify|record> [test_identifier ...]

Defaults to the full `ChromahoraTests/SnapshotTests` suite when no test identifiers are provided.
Failed comparisons write the new image to `.build/snapshot-failures` (override with SNAPSHOT_ARTIFACTS).

Examples:
  ./scripts/snapshots.sh verify
  ./scripts/snapshots.sh verify 'ChromahoraTests/SnapshotTests/afternoon()'
  ./scripts/snapshots.sh record
  ./scripts/snapshots.sh record 'ChromahoraTests/SnapshotTests/afternoon()'
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

if [ "$#" -eq 0 ]; then
  set -- "ChromahoraTests/SnapshotTests"
fi

only_testing=()
for test_name in "$@"; do
  only_testing+=("-only-testing:$test_name")
done

# Pinned rather than read from SIMULATOR: baselines only hold on the device they were
# recorded on, and fail anywhere else. Matches `snapshotDeviceName`.
snapshot_device="iPhone 18 Pro"

# shellcheck source=lib/testing.sh
source "$repo_root/scripts/lib/testing.sh"
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

# Time labels format with the process locale, so tests launch in the one the baselines use.
# Parallel testing boots slow simulator clones, and failure diagnostics take a sysdiagnose
# that stalls every failing run for about ten minutes.
run_snapshot_tests() {
  run_and_format xcodebuild \
    -project Chromahora.xcodeproj \
    -scheme Chromahora \
    -destination "platform=iOS Simulator,name=$snapshot_device" \
    -derivedDataPath .build/xcode \
    -testLanguage en \
    -testRegion US \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "${only_testing[@]}" \
    test \
    CODE_SIGNING_ALLOWED=NO
}

run_verify() {
  export TEST_RUNNER_SNAPSHOT_TESTING_RECORD=missing
  run_snapshot_tests
  require_every_test_ran "$raw_log"
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
run_snapshot_tests
record_status=$?
set -e

if [ "$record_status" -ne 0 ]; then
  echo "Snapshot record run exited $record_status; verifying recorded references..."
fi

run_verify
echo "Snapshots recorded and verified."
