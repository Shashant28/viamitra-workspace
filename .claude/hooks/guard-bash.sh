#!/usr/bin/env bash
# PreToolUse (Bash): block secret reads, destructive git/fs commands,
# and shell writes that touch protected paths.
source "$(dirname "$0")/lib.sh"

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[[ -z "$CMD" ]] && exit 0

block() { echo "BLOCKED: $1. Command: $CMD" >&2; exit 2; }

# 1) Secrets: any reference to a .env file other than .env.example
NO_EXAMPLE="${CMD//.env.example/}"
if [[ "$NO_EXAMPLE" =~ (^|[^A-Za-z0-9_])\.env([^A-Za-z0-9_]|$) || "$NO_EXAMPLE" =~ \.env\.(local|production|development|staging) ]]; then
  block "secret files (.env*) must not be read or touched; use .env.example for key names"
fi

# 1b) Guardrail internals: Claude must not run, inspect-and-rewrite, or reset its own hooks/snapshot
if [[ "$CMD" == *".claude/hooks"* || "$CMD" == *".claude/.state"* ]]; then
  block "guardrail scripts and their state are off-limits"
fi

# 2) Destructive / irreversible commands
DESTRUCTIVE='(^|[;&|[:space:]])(git[[:space:]]+push|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]]+-[a-z]*f|git[[:space:]]+checkout[[:space:]]+\.|git[[:space:]]+branch[[:space:]]+-D|rm[[:space:]]+-[a-z]*r[a-z]*f|rm[[:space:]]+-[a-z]*f[a-z]*r|sudo[[:space:]]|--no-verify|chmod[[:space:]]+-R[[:space:]]+777)'
if [[ "$CMD" =~ $DESTRUCTIVE ]]; then
  block "destructive or irreversible command; ask the human to run it"
fi
if [[ "$CMD" =~ (curl|wget)[^|]*\|[[:space:]]*(ba)?sh ]]; then
  block "piping remote scripts into a shell is not allowed"
fi

# 3) Writes that touch protected paths
WRITE_OPS='(^|[;&|[:space:]])(rm|mv|cp|tee|truncate|ln|unlink|install|rsync|touch|chmod|chown|sed[[:space:]]+-i|perl[[:space:]]+-[a-z]*i|git[[:space:]]+(checkout|restore|rm|mv|apply))([[:space:]]|$)|>'
if [[ "$CMD" =~ $WRITE_OPS ]]; then
  while IFS= read -r pat; do
    lit="${pat#\*\*/}"
    lit="${lit%%\**}"
    lit="${lit%/}"
    [[ ${#lit} -lt 4 ]] && continue
    if [[ "$CMD" == *"$lit"* ]]; then
      block "this command writes and references protected path '$pat'"
    fi
  done < <(load_patterns)
fi
exit 0
