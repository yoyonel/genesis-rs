# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-14

### Added

- **Platform support**: Debian, Arch Linux, Raspberry Pi OS (ARM64)
- **CLI**: `bootstrap` and `detect` subcommands via clap
- **Dry-run mode**: `--dry-run` flag to preview commands without execution
- **TOML configuration**: Per-platform package lists via `genesis.toml`
- **Structured logging**: `tracing` with `RUST_LOG` env control (stderr)
- **Hardware dashboard**: CPU, RAM, disk detection via `sysinfo`
- **Package validation**: Whitelist-based name validation (`[a-zA-Z0-9.+-]`)
- **CommandExecutor trait**: Abstraction for real, dry-run, and mock execution
- **AptPlatform**: Shared implementation for Debian/Raspbian (DRY)
- **E2E testing**: QEMU Cloud VMs + Cloud-Init + SSH deploy + SHA checksum verification
- **CI/CD pipeline**: 8-job GitHub Actions (quality, security, coverage, build, E2E×3)
- **Release workflow**: Tag-triggered multi-arch static binaries (x86_64 + aarch64 musl)
- **Documentation**: Rustdoc auto-deployed to GitHub Pages
- **Benchmarking**: Boot + deploy timing with QEMU metrics
- **VM management**: PID-based tracking and cleanup
- **Shellcheck**: Integrated linting for all 13 shell scripts
- **Coverage**: `cargo-tarpaulin` with HTML reports in CI artifacts
- **Pre-commit hooks**: `cargo fmt` + `clippy` + `actionlint` + `shellcheck`

[0.1.0]: https://github.com/yoyonel/genesis-rs/releases/tag/v0.1.0
