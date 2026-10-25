# ViaMitra Claude Code steering kit

Copy everything in this folder into the root of the ViaMitra repo, then:

```bash
chmod +x scripts/verify.sh .claude/hooks/*.sh
echo ".claude/.state/" >> .gitignore
echo "CLAUDE.local.md" >> .gitignore
echo ".claude/settings.local.json" >> .gitignore
git add -A && git commit -m "chore: add Claude Code steering kit"
```

Requirements: `bash` 4+, `jq` (`brew install jq` / `apt install jq`), git. On Windows use Git Bash or WSL.

## What's inside
| File | Purpose | Enforced how |
|---|---|---|
| `CLAUDE.md` | Short always-loaded rules + commands | Advisory (Claude reads it) |
| `.claude/rules/*.md` | Security (always), mobile / backend / dashboard (load only when those files are touched) | Advisory, path-scoped to save tokens |
| `.claude/protected-paths.txt` | Design assets, brand, secrets, guardrails | Hooks + deny rules (hard) |
| `.claude/settings.json` | Deny/ask/allow permissions + hooks | Hard |
| `.claude/hooks/protect-files.sh` | Blocks Edit/Write on protected paths | Hard (exit 2) |
| `.claude/hooks/guard-bash.sh` | Blocks .env access, destructive git/rm, shell writes into protected paths | Hard (exit 2), best-effort pattern match |
| `.claude/hooks/check-protected.sh` | At end of each turn, hashes protected files vs session snapshot; forces restore | Hard backstop for anything the first two miss |
| `.claude/hooks/session-start.sh` | Snapshots protected files; injects latest progress entry (also after /compact) | Hard |
| `.claude/agents/task-verifier.md` | Fresh-context review of diff vs Done-when + scope | On demand |
| `.claude/agents/security-reviewer.md` | Tenancy/auth/child-data review | On demand |
| `.claude/skills/next-task/` | `/next-task T1.3` — the full plan→build→verify→review→log loop | You invoke it |
| `scripts/verify.sh` | One command defines "done" | Required by rules + verifier |
| `docs/` | PRD, architecture, ADRs, tasks, progress log | Read on demand |
| `KICKOFF_PROMPT.md` | First-session prompt | — |

## Daily loop
1. `claude` → `/next-task` (or `/next-task T1.4`)
2. Review the plan it shows. Approve or correct.
3. When it says done: check the verify summary + task-verifier verdict, then commit/push yourself.
4. `/clear` before the next task. New task = fresh context.

## Changing protected things
You (the human) edit `design/`, assets, `DECISIONS.md`, `.claude/settings.json` directly in your editor. If you change a protected file while a session is running, the Stop hook will flag it — start a new session (or `/clear`) to re-baseline.
