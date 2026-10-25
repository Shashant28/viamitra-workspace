#!/usr/bin/env bash
# Shared helpers for ViaMitra guard hooks.
# Portable to macOS's bash 3.2: no globstar, no mapfile, no associative arrays.
# Requires: jq.

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PATTERNS_FILE="$ROOT/.claude/protected-paths.txt"
STATE_DIR="$ROOT/.claude/.state"
SNAPSHOT="$STATE_DIR/protected.sha"

load_patterns() {
  [[ -f "$PATTERNS_FILE" ]] || return 0
  sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e '/^$/d' "$PATTERNS_FILE"
}

PATTERNS=()
while IFS= read -r _p; do PATTERNS[${#PATTERNS[@]}]="$_p"; done < <(load_patterns)
unset _p

to_rel() {
  local p="${1//\\//}"
  local r="${ROOT//\\//}"
  p="${p#"$r"/}"
  p="${p#./}"
  printf '%s' "$p"
}

is_protected() {
  local rel="$1" pat tail
  for pat in "${PATTERNS[@]}"; do
    if [[ "$rel" == $pat || "$rel" == $pat/* ]]; then echo "$pat"; return 0; fi
    if [[ "$pat" == '**/'* ]]; then
      tail="${pat#\*\*/}"
      if [[ "$rel" == $tail || "$rel" == $tail/* ]]; then echo "$pat"; return 0; fi
    fi
  done
  return 1
}

list_protected_files() {
  (
    cd "$ROOT" || exit 0
    find . \
      \( -name .git -o -name node_modules -o -name .venv -o -name Pods -o -name .state \
         -o -path './apps/*/android/build' -o -path './apps/*/ios/build' \) -prune -o \
      -type f -print 2>/dev/null \
    | sed 's#^\./##' \
    | while IFS= read -r f; do
        is_protected "$f" >/dev/null && echo "$f"
      done
  ) | sort -u
}

hash_files() {
  local hasher
  if command -v sha256sum >/dev/null 2>&1; then hasher="sha256sum"; else hasher="shasum -a 256"; fi
  (cd "$ROOT" && while IFS= read -r f; do $hasher "$f"; done)
}

snapshot_protected() {
  mkdir -p "$STATE_DIR"
  list_protected_files | hash_files > "$SNAPSHOT"
}
