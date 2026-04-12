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

## Documentation (MANDATORY — as important as the code itself)

**Documentation is NOT optional. It is a first-class deliverable, as important as — or MORE important than — the code itself.**

### Documentation Gate (blocks PR merge)

A PR is NOT ready for merge unless ALL applicable documentation is included:

1. **README.md** — Must reflect the current state of the project at all times:
   - CLI flags and subcommands (full `--help` equivalent)
   - Configuration file format and options
   - New Justfile recipes
   - Test count and coverage
   - Architecture diagrams if structure changed
2. **API Documentation** — Every public function, trait, struct, and module MUST have rustdoc comments:
   - `///` on all `pub` items in `src/`
   - Module-level `//!` docs in every `.rs` file
   - Usage examples in doc comments for non-trivial APIs
   - Run `cargo doc --no-deps` and verify no warnings
3. **Configuration Documentation** — Any config file (TOML, YAML, etc.) must have:
   - A documented example file with comments explaining every field
   - A dedicated section in README.md explaining usage, defaults, and override behavior
4. **Scripts Documentation** — Every script in `scripts/` must have:
   - A usage comment header (already enforced)
   - Be listed in README.md project structure if new
5. **docs/ Folder** — Must be updated in the **same PR** as the code change when:
   - Architecture changes (new traits, modules, platforms)
   - New scripts or Justfile recipes added
   - CI/CD workflow changes
   - Benchmark methodology or results change
6. **Changelog** — `docs/github-settings.md` must reflect any label/milestone/project changes

### Documentation Review Checklist

Before marking a PR ready:
- [ ] `cargo doc --no-deps` builds with zero warnings
- [ ] README.md sections are up-to-date (features, CLI, config, project structure, test count)
- [ ] New public APIs have rustdoc with examples
- [ ] Config files have documented examples
- [ ] `docs/` updated if architecture/scripts/CI changed
