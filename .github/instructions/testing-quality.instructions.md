---
description: "Use when running tests, validating refactoring, checking code quality, or completing any task. Covers CI validation, test coverage, and quality gates."
applyTo: ["src/**/*.rs", "tests/**/*.rs", "scripts/*.sh", "Justfile"]
---
# Testing & Quality Gates

## CI IS THE SINGLE SOURCE OF TRUTH (NO EXCEPTIONS)

**A task (prompt, refactoring, fix, feature, docs) is NEVER complete until the CI pipeline is fully green.**
This is an absolute, non-negotiable rule with ZERO exceptions:
- All jobs must pass: Quality Gate, Build, AND all E2E Verify jobs
- A red CI means the task is still **in progress**, regardless of local test results
- Do NOT merge, do NOT close issues, do NOT mark tasks as done with red CI
- If CI fails after merge to master, a hotfix PR is mandatory — master must be green at all times

## Validation Checklist (every change)

Run locally before pushing:
```bash
just format         # Auto-fix formatting
just lint           # clippy + actionlint + format-check (0 warnings)
just test           # All unit + integration + CLI tests pass
```

After push, monitor CI: `gh run watch` or `gh run list --limit 1`.

## Test Coverage

- **Never decrease test coverage.** Every new function/method in `src/` must have corresponding tests.
- When refactoring: run `just test` before AND after — same test count, same results.
- When adding a feature: add unit tests in the same PR. No "tests in a follow-up" pattern.
- Track coverage: `cargo tarpaulin --out Html` when available.

## Code Quality Standards

- Zero `clippy` warnings (`-D warnings` — enforced by CI)
- Zero `cargo fmt` diff (enforced by CI)
- No `unwrap()` in `src/` (library code) — only in `tests/`
- `anyhow::Result` for error propagation
- `cargo audit` clean (no known vulnerabilities)

## Justfile Discipline

- Recipes are thin entry points (max ~5 lines of shell)
- Complex logic goes to `scripts/*.sh`
- New scripts must be executable (`chmod +x`) and have a usage comment header
- Test new Justfile recipes locally before pushing

## E2E Test Hygiene

- Overlay reset before every E2E run (idempotent tests)
- SSH key injection is dynamic (placeholder in `user-data`, replaced at provision time)
- Never hardcode keys, passwords, or environment-specific values in committed files

## Documentation Sync (MANDATORY)

- `docs/` must be updated in the **same PR** as the code change when:
  - Architecture changes (new traits, modules, platforms)
  - New scripts or Justfile recipes added
  - CI/CD workflow changes
  - Benchmark methodology or results change
- `docs/github-settings.md` must reflect any label/milestone/project changes
- `docs/audit-phase1.md` scoring must be updated when audit items are resolved
