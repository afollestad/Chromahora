# shellcheck shell=bash
# Shared by test.sh and snapshots.sh, which source it after `cd`-ing to the repo root.

# Failed snapshot comparisons write the new image here, and a run's images replace the last
# run's, so they always describe its failures. A custom SNAPSHOT_ARTIFACTS is left alone.
# The simulator doesn't inherit this shell's environment; xcodebuild forwards `TEST_RUNNER_`
# variables with the prefix stripped. The path is absolute, since the test host resolves a
# relative one against its own directory.
prepare_snapshot_artifacts() {
  local default_artifacts="$PWD/.build/snapshot-failures"
  local artifacts=${SNAPSHOT_ARTIFACTS:-$default_artifacts}
  if [ "$artifacts" = "$default_artifacts" ]; then
    rm -rf "$artifacts"
  fi
  mkdir -p "$artifacts"
  TEST_RUNNER_SNAPSHOT_ARTIFACTS=$(cd "$artifacts" && pwd)
  export TEST_RUNNER_SNAPSHOT_ARTIFACTS
}

# xcodebuild exits 0 when an identifier matches nothing or a test is skipped, which would
# read as a pass. Matches Swift Testing's own console lines in the raw log, which xcodebuild
# prints with parallel testing off.
require_every_test_ran() {
  local raw_log=$1
  if grep -Eq "^➜ Test .+ skipped" "$raw_log"; then
    echo "error: some tests were skipped:" >&2
    grep -E "^➜ Test .+ skipped" "$raw_log" >&2
    exit 1
  fi
  if ! grep -Eq "^✔ Test run with [1-9][0-9]* tests? " "$raw_log"; then
    echo "error: no tests ran. Check the test identifiers." >&2
    exit 1
  fi
}
