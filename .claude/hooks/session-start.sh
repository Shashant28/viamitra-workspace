#!/usr/bin/env bash
# SessionStart (startup|resume|clear|compact): snapshot protected files and
# inject a short, token-cheap reminder + the latest progress entry.
source "$(dirname "$0")/lib.sh"

SOURCE=$(jq -r '.source // "startup"' 2>/dev/null)
SOURCE="${SOURCE:-startup}"

# Snapshot only on a fresh start/clear so mid-session violations stay detectable.
if [[ "$SOURCE" == "startup" || "$SOURCE" == "clear" || ! -f "$SNAPSHOT" ]]; then
  snapshot_protected
fi

echo "ViaMitra reminders: one task at a time from docs/TASKS.md; verify APIs before use (no invented APIs/packages); never modify .claude/protected-paths.txt paths; finish with ./scripts/verify.sh + a PROGRESS.md entry."
if [[ -f "$ROOT/docs/PROGRESS.md" ]]; then
  echo "--- Latest progress entry ---"
  awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/{n++} n==1{print} n==2{exit}' "$ROOT/docs/PROGRESS.md" | head -n 15
fi
exit 0
