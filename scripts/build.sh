#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    raw_log=$(mktemp -t chromahora-xcodebuild.XXXXXX)
    filtered_log=$(mktemp -t chromahora-xcsift.XXXXXX)
    trap 'rm -f "$raw_log" "$filtered_log"' EXIT
    set +e
    "$@" 2>&1 | tee "$raw_log" | xcsift -f toon -w | tee "$filtered_log"
    statuses=("${PIPESTATUS[@]}")
    set -e

    status=0
    for pipeline_status in "${statuses[@]}"; do
      if [ "$pipeline_status" -ne 0 ]; then
        status=$pipeline_status
      fi
    done

    if [ "$status" -ne 0 ]; then
      xcodebuild_status=${statuses[0]:-0}
      if [ "$xcodebuild_status" -ne 0 ] && [ ! -s "$filtered_log" ]; then
        echo "" >&2
        echo "xcodebuild exited $xcodebuild_status and xcsift produced no output - raw log:" >&2
        cat "$raw_log" >&2
      fi
      exit "$status"
    fi
  else
    "$@"
  fi
}

run_and_format xcodebuild \
  -project Chromahora.xcodeproj \
  -scheme Chromahora \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/xcode \
  build \
  CODE_SIGNING_ALLOWED=NO \
  "$@"
