# genesis-rs — Project Guidelines

## Project Context

Linux bootstrap/provisioning tool (Debian, Arch, Raspbian) in Rust.
Repository: [yoyonel/genesis-rs](https://github.com/yoyonel/genesis-rs).

## Roadmap & Project Tracking

**CRITICAL**: At the start of every session, consult the GitHub project board and milestones:
- Project board: https://github.com/users/yoyonel/projects/2
- Milestones: `gh api repos/yoyonel/genesis-rs/milestones?state=all`
- Open issues: `gh issue list --state open`
- Refer to [docs/github-settings.md](docs/github-settings.md) for label taxonomy and project structure.
- Refer to [docs/audit-phase1.md](docs/audit-phase1.md) for the baseline audit and improvement plan.

## Architecture

- Trait `SystemPlatform` with impls per distro (Debian, Arch, Raspbian).
- `CommandExecutor` trait for testability (mock system calls).
- CLI via clap derive in `src/cli.rs`.
- Build targets: `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`.
- E2E: QEMU Cloud VMs + Cloud-Init + SSH-based deploy.

## Build & Test

```bash
just check          # Compile check
just test           # Unit + integration tests
just lint           # clippy + actionlint + format-check
just format         # cargo fmt
just build          # Release build (x86_64)
just build-arm      # Release build (aarch64)
just ci-test <os>   # Full E2E cycle (debian|arch|raspbian)
just benchmark <os> # Benchmark with metrics
```

## Code Style

- Rust 2024 edition. Follow standard `rustfmt` and `clippy` conventions.
- Zero clippy warnings (`-D warnings`).
- Prefer `anyhow::Result` for error propagation.
- No `unwrap()` in library code — only in tests.

## Justfile Philosophy

Keep Justfile recipes as **thin entry points**. Any recipe exceeding ~5 lines of shell MUST be extracted to `scripts/*.sh`. The Justfile should read like a table of contents, not contain business logic.

## Commit Conventions

**Separation of Concerns (SoC) is mandatory.** Never mix different concerns in one commit:
- `feat:` for application code
- `fix:` for bug fixes
- `refactor:` for restructuring
- `docs:` for documentation
- `ci:` for CI/CD workflows
- `test:` for test additions/changes
- `chore:` for tooling, scripts, dependencies

**Never `git push` without explicit user authorization.**
