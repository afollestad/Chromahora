#!/bin/bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

simulator_name=${SIMULATOR:-"iPhone 18 Pro"}

run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    "$@" 2>&1 | xcsift -f toon -w
  else
    "$@"
  fi
}

only_testing=(-only-testing:ChromahoraTests)
if [ "$#" -gt 0 ]; then
  only_testing=()
  for test_name in "$@"; do
    only_testing+=("-only-testing:$test_name")
  done
fi

run_and_format xcodebuild \
  -project Chromahora.xcodeproj \
  -scheme Chromahora \
  -destination "platform=iOS Simulator,name=$simulator_name" \
  -derivedDataPath .build/xcode \
  "${only_testing[@]}" \
  test \
  CODE_SIGNING_ALLOWED=NO

echo "Tests passed."
