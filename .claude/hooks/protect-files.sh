#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit): block edits to protected paths.
source "$(dirname "$0")/lib.sh"

INPUT=$(cat)
FILE=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$INPUT")
[[ -z "$FILE" ]] && exit 0

REL=$(to_rel "$FILE")
if [[ "$REL" == .claude/.state* ]]; then
  echo "BLOCKED: guardrail state is off-limits." >&2; exit 2
fi
if PAT=$(is_protected "$REL"); then
  echo "BLOCKED: '$REL' is protected (pattern '$PAT' in .claude/protected-paths.txt). Do not modify it by any other means. If the task truly needs a change here, stop and ask the human." >&2
  exit 2
fi
exit 0
