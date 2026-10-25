# Kickoff prompt (paste into Claude Code, first session, plan mode)

Start with: `claude --permission-mode plan`

---

You are the lead engineer on ViaMitra. Before writing any code:

1. Read CLAUDE.md, docs/PRD.md, docs/ARCHITECTURE.md, docs/DECISIONS.md, docs/TASKS.md and docs/PROGRESS.md. Run /context and confirm CLAUDE.md and .claude/rules/security.md loaded.
2. Interview me with the AskUserQuestion tool about anything in these docs that is ambiguous, contradictory, or missing for Phase 0 (e.g. Node/Python versions, package manager versions, Android test devices, AWS account status). Don't ask what the docs already answer. Max 8 questions.
3. Then produce a review, not code:
   - Gaps or risks in TASKS.md Phase 0–1 (missing tasks, wrong order, Done-when that can't be verified by a command).
   - For each library in DECISIONS.md: the exact package name you'd install and the latest stable version, verified with `npm view` / `pip index versions`. Mark anything you couldn't verify as UNVERIFIED.
   - Anything in the docs you believe is wrong, as a proposed ADR (don't edit DECISIONS.md).
4. Stop and wait for my approval. After I approve, we work strictly one task at a time with /next-task, starting at T0.1.

Ground rules for this whole project: no invented APIs or packages; stay inside each task's Files; never touch protected paths; "done" only with ./scripts/verify.sh output; if unsure, ask instead of guessing.
