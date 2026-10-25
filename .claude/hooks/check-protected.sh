#!/usr/bin/env bash
# Stop: compare protected files with the session-start snapshot.
# Catches changes made by any route (Bash, scripts, generators), not just Edit/Write.
source "$(dirname "$0")/lib.sh"

INPUT=$(cat)
ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")

[[ -f "$SNAPSHOT" ]] || exit 0
CURRENT=$(list_protected_files | hash_files)
DIFF=$(diff <(cat "$SNAPSHOT") <(printf '%s\n' "$CURRENT") | grep -E '^[<>]' | awk '{print $NF}' | sort -u)
[[ -z "$DIFF" ]] && exit 0

MSG="Protected files changed during this session: $(echo "$DIFF" | tr '\n' ' ')"
if [[ "$ACTIVE" == "true" ]]; then
  # Already asked once; don't loop. Surface to the human instead.
  jq -n --arg m "$MSG — please review. If you (the human) changed them, start a new session or /clear to re-baseline." '{systemMessage: $m}'
  exit 0
fi
echo "$MSG. Restore them now (git checkout -- <file> for tracked files, delete new files you created there) and explain in PROGRESS.md how it happened. If the human changed them, say so and stop." >&2
exit 2
