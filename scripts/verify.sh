#!/usr/bin/env bash
# Single source of truth for "done": runs every repo's own scripts/check.sh.
# A missing repo or check script is a failure, and skipped backend tests fail (CHECK_NO_SKIPS=1).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPOS=(viamitra-backend viamitra-mobile viamitra-web)
FAIL=0
results=()

for repo in "${REPOS[@]}"; do
  echo
  echo "################ $repo ################"
  if [[ ! -f "$repo/scripts/check.sh" ]]; then
    results+=("FAIL  $repo (scripts/check.sh not found)")
    FAIL=1
    continue
  fi
  if CHECK_NO_SKIPS=1 bash "$repo/scripts/check.sh"; then
    results+=("PASS  $repo")
  else
    results+=("FAIL  $repo")
    FAIL=1
  fi
done

echo
echo "===== verify summary ====="
printf '%s\n' "${results[@]}"
exit $FAIL
