#!/bin/sh
set -eu

hooks_dir=$(git rev-parse --git-path hooks)
pre_commit="$hooks_dir/pre-commit"

mkdir -p "$hooks_dir"

cat > "$pre_commit" <<'HOOK'
#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# Branches without the app, like `gh-pages`, have no lint script and nothing for it to lint.
if [ -f ./scripts/lint.sh ]; then
  ./scripts/lint.sh --quiet
fi
git diff --cached --check
HOOK

chmod +x "$pre_commit"

echo "Installed git pre-commit hook."
