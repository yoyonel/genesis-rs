# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **RPi4 QEMU fallback**: Automatic fallback to QEMU ARM64 emulation on GitHub-hosted runners when the self-hosted RPi4 runner is unavailable. 3-tier detection: API check (optional `RUNNER_ADMIN_TOKEN`), repository variable (`vars.RPI4_RUNNER`), default QEMU.
- **RPi4 runner documentation**: New `docs/rpi4-runner.md` covering hardware specs, installation procedure, CI/CD workflow architecture, configuration, and troubleshooting.

## [0.2.0] - 2026-04-15

### Added

- **`--verbose` / `-v` CLI flag**: Global flag that switches logging from INFO to DEBUG level. `RUST_LOG` still takes precedence. Debug messages added to platform detection and config loading.
- **`.deb` packaging**: `cargo-deb` integration with `[package.metadata.deb]` in Cargo.toml. Binary installs to `/usr/bin/`, docs to `/usr/share/doc/genesis-rs/`. Justfile recipe: `just package-deb`.
- **AUR PKGBUILD**: `packaging/arch/PKGBUILD` for Arch Linux users. Builds from source with `cargo build --release`, runs tests in `check()`. Installable via `makepkg -si`. Justfile recipe: `just package-arch`.
- **MIT LICENSE file**: Added explicit license file for packaging compliance.
- **Release CI**: `.deb` build job added to `release.yml`, attached to GitHub releases alongside raw binaries.
- **Package metadata**: `description`, `homepage`, `repository` fields added to `Cargo.toml`.

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

[0.2.0]: https://github.com/yoyonel/genesis-rs/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yoyonel/genesis-rs/releases/tag/v0.1.0
