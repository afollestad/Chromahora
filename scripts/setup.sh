#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required. Install it from https://brew.sh/ and rerun this script." >&2
  exit 1
fi

install_brew_formula() {
  formula=$1
  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "$formula already installed"
  else
    brew install "$formula"
  fi
}

install_brew_formula xcsift
install_brew_formula swiftlint

"$repo_root/scripts/install-git-hooks.sh"

echo "Setup complete. Next steps:"
echo "  1. Build with ./scripts/build.sh"
echo "  2. Run in the simulator with ./scripts/run.sh"
echo "  3. Test with ./scripts/test.sh"
echo "  4. Lint with ./scripts/lint.sh"
