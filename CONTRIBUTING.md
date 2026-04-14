# Contributing to genesis-rs

Thank you for your interest in contributing to genesis-rs!

## Development Setup

```bash
# Clone the repository
git clone https://github.com/yoyonel/genesis-rs.git
cd genesis-rs

# Install Rust + just
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install just

# Install all system dependencies (QEMU, musl, etc.)
just setup

# Run the full validation suite
just format && just lint && just test
```

## Workflow

1. **Create an issue** describing the problem or feature
2. **Create a branch** from `master`:
   - `feat/<description>` for features
   - `fix/<description>` for bug fixes
   - `refactor/<description>` for restructuring
   - `docs/<description>` for documentation
   - `ci/<description>` for CI/CD changes
3. **Implement** in small, focused commits (see Commit Convention below)
4. **Open a PR** with:
   - Labels (at least one scope + one type)
   - Milestone (if applicable)
   - `Closes #N` in the PR body
5. **CI must be green** before merge

## Commit Convention

Every commit must follow the [Conventional Commits](https://www.conventionalcommits.org/) prefix convention:

| Prefix | Usage |
|:---|:---|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `refactor:` | Code restructuring |
| `docs:` | Documentation only |
| `ci:` | CI/CD changes |
| `test:` | Test additions/changes |
| `chore:` | Tooling, deps, maintenance |
| `deps:` | Dependency updates |
| `security:` | Security fixes |

**Separation of Concerns (SoC)**: Never mix application code, CI, docs, or tests in the same commit.

## Quality Gates

Before pushing, always run:

```bash
just format         # Auto-fix formatting
just lint           # clippy + actionlint + shellcheck (0 warnings)
just test           # All unit + integration tests pass
```

A pre-commit hook enforces these checks automatically (`just install-hooks`).

## Code Standards

- Zero `clippy` warnings (`-D warnings`)
- Zero `cargo fmt` diff
- No `unwrap()` in `src/` — use `anyhow::Result`
- All `pub` items must have `///` rustdoc comments
- Package names validated by whitelist (`[a-zA-Z0-9.+-]`)

## Testing

- Every new function in `src/` must have corresponding tests
- Never decrease test coverage
- Use `MockExecutor` for unit testing platform operations
- Run E2E tests with `just ci-test <os>` (requires QEMU)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
