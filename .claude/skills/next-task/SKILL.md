---
name: next-task
description: Run the standard ViaMitra task loop for one task from docs/TASKS.md (plan, implement, verify, review, log).
disable-model-invocation: true
---

Task: $ARGUMENTS (if empty, pick the first `[ ]` task in `docs/TASKS.md` whose Depends are all `[x]`).

1. **Load**: read the top entry of `docs/PROGRESS.md` and this task only. Mark it `[~]`. Create branch `task/<ID>-<short-name>`.
2. **Explore** (read-only): use the Explore subagent if you need to look across more than ~5 files. Read installed type definitions / docs for every library API you plan to call.
3. **Plan**: write a short plan: files to change (must be inside the task's Files), functions/endpoints, tests that prove Done-when, risks. List anything UNVERIFIED. If the plan needs files outside scope or a new dependency, STOP and ask.
4. **Implement** in small steps. Write/extend tests first where practical.
5. **Verify**: run the task's Done-when command(s) and `./scripts/verify.sh`. Fix root causes until both pass. Paste the summary lines.
6. **Review**: run the `task-verifier` subagent with this task ID. If the task touches auth, tenancy, workers, MQTT or token storage, also run `security-reviewer`. Fix every FAIL that affects correctness/security/scope; re-run verify.
7. **Log**: mark the task `[x]` (or `[!]` with reason), add the PROGRESS.md entry using the template, then propose a commit message (Conventional Commits). Don't push.
