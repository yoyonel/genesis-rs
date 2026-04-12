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
- `CommandExecutor` trait for testability (real, dry-run, mock).
- `Config` loaded from TOML (`genesis.toml`) for per-platform package lists.
- CLI via clap derive in `src/cli.rs` (global flags: `--dry-run`, `--config`).
- Structured logging via `tracing` (stderr, controlled by `RUST_LOG`).
- Build targets: `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`.
- E2E: QEMU Cloud VMs + Cloud-Init + SSH-based deploy + SHA checksum verification.

## Build & Test

```bash
just check          # Compile check
just test           # Unit + integration tests (37 tests)
just lint           # clippy + actionlint + format-check
just format         # cargo fmt
just build          # Release build (x86_64)
just build-arm      # Release build (aarch64)
just ci-test <os>   # Full E2E cycle (debian|arch|raspbian)
just benchmark <os> # Benchmark with metrics
```

## Detailed Rules (see instruction files)

The following instruction files contain the authoritative, detailed rules. **Do not duplicate their content here.**

- **[commit-workflow.instructions.md](instructions/commit-workflow.instructions.md)** — SoC commit discipline, Agile workflow, branching strategy, git safety rules.
- **[testing-quality.instructions.md](instructions/testing-quality.instructions.md)** — CI validation, test coverage, code quality standards, Justfile discipline, **documentation gates**.
- **[github-project.instructions.md](instructions/github-project.instructions.md)** — PR workflow, labels, milestones, project board management.
