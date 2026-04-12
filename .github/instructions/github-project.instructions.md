---
description: "Use when creating PRs, closing issues, updating milestones, or managing GitHub project board items. Covers label assignment, project tracking, and milestone lifecycle."
---
# GitHub Project Management

## Session Startup (MANDATORY)

At the start of **every** session, run:
```bash
gh issue list --state open
gh api repos/yoyonel/genesis-rs/milestones?state=all --jq '.[] | "\(.number) \(.title) \(.state) \(.open_issues)/\(.open_issues + .closed_issues)"'
```
Review the project board: https://github.com/users/yoyonel/projects/2

## PR Workflow

Every PR **MUST** have:
- **Labels**: at least one scope (`platform:*`, `infra:*`, `scope:*`) + one type (`bug`, `enhancement`, `refactor`, `quality`, `security`, `documentation`)
- **Milestone**: linked to the relevant phase
- **Project**: added to "genesis-rs Refactoring Roadmap" (project #2)
- **Linked issues**: use `Closes #N` in PR body for auto-closing

Label reference: see [docs/github-settings.md](../../docs/github-settings.md).

## Issue Lifecycle

- When starting work on an issue: move to "In Progress" on the project board
- When PR is merged: verify the linked issue auto-closed; if not, close manually
- When all issues in a milestone are closed: close the milestone

## Branch Naming

- `feat/<description>` for features
- `fix/<description>` for bug fixes
- `refactor/<description>` for restructuring
- `docs/<description>` for documentation-only
- `ci/<description>` for CI/CD changes
