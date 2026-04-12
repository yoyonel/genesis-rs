---
description: "Use when making commits, creating branches, or planning work iterations. Covers SoC commit discipline, Agile workflow, and branching strategy."
---
# Commit & Agile Workflow

## Separation of Concerns (SoC) — MANDATORY

Every commit must have a **single concern**. Never mix:
- Application code (`feat:`, `fix:`, `refactor:`) with CI (`ci:`) or docs (`docs:`)
- Test changes (`test:`) with the code they test (separate commits when possible)
- Script/tooling changes (`chore:`) with application logic

Prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `ci:`, `test:`, `chore:`

## Agile Iteration Model

Work follows the milestone phases defined in GitHub:
1. Pick an issue from the current open milestone
2. Create a branch (`feat/`, `fix/`, `refactor/`, etc.)
3. Implement in small, focused commits (SoC)
4. Open PR with labels + milestone + project link
5. CI must be green before merge
6. After merge: verify issue auto-closed, update project board

## Never Push Directly to Master

- All changes go through PRs — even hotfixes
- PR must reference the issue it resolves (`Closes #N`)
- Fast-forward merge preferred (rebase before merge if needed)

## Git Safety Rules

- **Never `git push` without explicit user authorization**
- **Never `git push --force`** without explicit user authorization
- **Never delete untracked files** without asking
- Prefer `git stash` over discarding changes
