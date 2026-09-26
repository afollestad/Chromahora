#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

simulator_name=${SIMULATOR:-"iPhone 18 Pro"}

# shellcheck source=lib/testing.sh
source "$repo_root/scripts/lib/testing.sh"
prepare_snapshot_artifacts

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

only_testing=(-only-testing:ChromahoraTests)
if [ "$#" -gt 0 ]; then
  only_testing=()
  for test_name in "$@"; do
    only_testing+=("-only-testing:$test_name")
  done
fi

# Snapshot baselines only hold on the device they were recorded on (`snapshotDeviceName`),
# and fail anywhere else, so another SIMULATOR leaves them out.
if [ "$simulator_name" != "iPhone 18 Pro" ]; then
  echo "Skipping ChromahoraTests/SnapshotTests: baselines are recorded on iPhone 18 Pro, not $simulator_name."
  only_testing+=(-skip-testing:ChromahoraTests/SnapshotTests)
fi

# Parallel testing runs on simulator clones, which boot slowly and shut the original down.
# Failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.
run_and_format xcodebuild \
  -project Chromahora.xcodeproj \
  -scheme Chromahora \
  -destination "platform=iOS Simulator,name=$simulator_name" \
  -derivedDataPath .build/xcode \
  -testLanguage en \
  -testRegion US \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  "${only_testing[@]}" \
  test \
  CODE_SIGNING_ALLOWED=NO

require_every_test_ran "$raw_log"
echo "Tests passed."
