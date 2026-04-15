# RPi4 Self-Hosted Runner — Setup & CI/CD Workflow

This document describes the Raspberry Pi 4 self-hosted GitHub Actions runner used for
native ARM64 E2E testing, and the QEMU fallback mechanism that ensures CI resilience.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Hardware Specifications](#hardware-specifications)
- [Installation Procedure](#installation-procedure)
- [CI/CD Workflow — Fallback Strategy](#cicd-workflow--fallback-strategy)
- [Configuration](#configuration)
- [Maintenance & Troubleshooting](#maintenance--troubleshooting)

## Architecture Overview

The Raspbian E2E test has two execution paths:

```
┌──────────────────────────────────────────────────────────┐
│                    check-rpi4 job                        │
│         (ubuntu-latest, checks runner availability)      │
│                                                          │
│  Tier 1: API check (RUNNER_ADMIN_TOKEN secret)           │
│  Tier 2: Static override (vars.RPI4_RUNNER = true)       │
│  Tier 3: Default → QEMU fallback                        │
└───────────────┬──────────────────────┬───────────────────┘
                │ available=true       │ available!=true
                ▼                      ▼
┌───────────────────────┐  ┌───────────────────────────────┐
│  e2e-raspbian         │  │  e2e-raspbian-qemu            │
│  (bare-metal ARM64)   │  │  (QEMU ARM64 on ubuntu-latest)│
│                       │  │                               │
│  • Self-hosted RPi4   │  │  • GitHub-hosted x86 runner   │
│  • Native execution   │  │  • qemu-system-aarch64 (TCG)  │
│  • ~30s total         │  │  • Full VM provisioning       │
│  • Direct binary run  │  │  • ~5-8 min total             │
└───────────────────────┘  └───────────────────────────────┘
```

**Key principle**: CI never gets stuck. If the RPi4 is offline, QEMU takes over
automatically. The bare-metal path is preferred when available (faster, native).

## Hardware Specifications

| Component        | Details                                 |
|------------------|-----------------------------------------|
| **Model**        | Raspberry Pi 4 Model B Rev 1.2          |
| **SoC**          | BCM2711 (4-core ARM Cortex-A72)         |
| **RAM**          | 3.7 GB (+ 2 GB swap)                   |
| **OS**           | Raspberry Pi OS 11.11 (bullseye) arm64  |
| **KVM**          | Available (`/dev/kvm` present)          |
| **Network**      | LAN (192.168.x.x), internet access      |
| **Other roles**  | Prometheus + Grafana monitoring stack   |
| **Runner name**  | `genesis-rpi4`                          |
| **Labels**       | `self-hosted`, `linux`, `ARM64`, `rpi4` |

## Installation Procedure

### Prerequisites

The RPi4 must have internet access and be able to reach `github.com`.

### Step 1 — Increase swap (recommended)

The default 100 MB swap is insufficient. Increase to 2 GB:

```bash
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
free -h  # verify: Swap: 2.0Gi
```

### Step 2 — Install required packages

```bash
# jq is needed for CI scripts
brew install jq  # or: sudo apt-get install -y jq
```

> **Note**: No QEMU or Rust toolchain is needed on the RPi4. The binary is a
> statically-linked musl executable cross-compiled on the GitHub-hosted runner
> and downloaded as an artifact. The RPi4 just executes it natively.

### Step 3 — Create a registration token

From a machine with `gh` CLI access to the repository:

```bash
gh api repos/yoyonel/genesis-rs/actions/runners/registration-token \
  --method POST --jq '.token'
```

This token expires after 1 hour. Use it immediately in the next step.

### Step 4 — Download and configure the runner

SSH into the RPi4 and run:

```bash
# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the latest ARM64 runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz" | tar xz

# Configure
./config.sh \
  --url https://github.com/yoyonel/genesis-rs \
  --token <REGISTRATION_TOKEN> \
  --name genesis-rpi4 \
  --labels self-hosted,linux,ARM64,rpi4 \
  --unattended
```

### Step 5 — Install as a systemd service

```bash
sudo ./svc.sh install $USER
sudo ./svc.sh start
sudo ./svc.sh status   # Should show: Active: active (running)
```

### Step 6 — Verify from GitHub

```bash
# From your development machine
gh api repos/yoyonel/genesis-rs/actions/runners \
  --jq '.runners[] | "\(.name) \(.status) [\(.labels | map(.name) | join(", "))]"'
# Expected: genesis-rpi4 online [self-hosted, Linux, ARM64, rpi4]
```

## CI/CD Workflow — Fallback Strategy

### How it works

The `check-rpi4` job runs on `ubuntu-latest` (fast, always available) and determines
which execution path to use through a 3-tier check:

1. **Tier 1 — Dynamic API check** (optional, best experience):
   If the `RUNNER_ADMIN_TOKEN` secret is configured, the job queries the GitHub API
   to check if a runner with the `rpi4` label is currently `online`.

2. **Tier 2 — Static override** (simple, no token needed):
   If the `RPI4_RUNNER` repository variable is set to `true`, the job assumes the
   runner is available. This is the recommended default configuration.

3. **Tier 3 — QEMU fallback** (safe default):
   If neither Tier 1 nor Tier 2 indicate availability, the QEMU fallback is used.
   This is the default behavior when no configuration exists.

### Bare-metal path (preferred)

When the RPi4 is available:
1. The `e2e-raspbian` job runs on `[self-hosted, linux, ARM64]`
2. Downloads the pre-built `aarch64-unknown-linux-musl` binary artifact
3. Executes `genesis-rs detect` directly on the RPi4 — no VM, no emulation
4. Validates output contains `SYSTEM SUMMARY` and `DEBUG` (verbose mode)
5. Total time: ~30 seconds

### QEMU path (fallback)

When the RPi4 is unavailable:
1. The `e2e-raspbian-qemu` job runs on `ubuntu-latest`
2. Installs QEMU ARM64 packages: `qemu-system-arm`, `qemu-efi-aarch64`, `qemu-utils`, `genisoimage`
3. Provisions a Raspbian ARM64 cloud VM (`just provision-raspbian`):
   - Downloads Debian 12 ARM64 cloud image
   - Creates QCOW2 overlay for idempotent testing
   - Generates cloud-init seed ISO
   - Prepares AAVMF EFI firmware
4. Runs full E2E cycle (`just ci-test raspbian 22223 aarch64-unknown-linux-musl "true"`):
   - Boots VM with `qemu-system-aarch64` in TCG mode (software emulation)
   - Waits for SSH availability
   - Deploys binary via SCP and runs `genesis-rs detect`
   - Cleans up VM
5. Total time: ~5-8 minutes (TCG is 10-20x slower than native)

### Execution flow diagram

```
push/PR to master
       │
       ▼
   ┌────────┐     ┌──────────┐     ┌───────┐
   │quality ├────►│  build   ├────►│ check │
   └────────┘     │(x86+arm) │     │ rpi4  │
                  └─────┬────┘     └───┬───┘
                        │              │
                        ▼              ▼
                  ┌──────────┐   ┌──────────────┐
                  │ e2e-test │   │ e2e-raspbian  │ (if available)
                  │(deb+arch)│   │ (bare-metal)  │
                  └──────────┘   └──────────────┘
                                        OR
                                 ┌──────────────┐
                                 │ e2e-raspbian  │ (if NOT available)
                                 │ (QEMU)        │
                                 └──────────────┘
```

## Configuration

### Repository variable: `RPI4_RUNNER` (recommended)

Go to **Settings → Secrets and variables → Actions → Variables → New repository variable**:
- **Name**: `RPI4_RUNNER`
- **Value**: `true`

Set to `true` when the RPi4 is online. Remove or set to anything else to force QEMU fallback.

### Secret: `RUNNER_ADMIN_TOKEN` (optional, advanced)

For fully automatic detection, create a fine-grained Personal Access Token:
1. Go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token scoped to `yoyonel/genesis-rs` with **Administration: Read** permission
3. Add it as a repository secret named `RUNNER_ADMIN_TOKEN`

With this token, the CI dynamically checks if the RPi4 runner is online — no manual
variable toggling needed.

## Maintenance & Troubleshooting

### Check runner status

```bash
# From GitHub API
gh api repos/yoyonel/genesis-rs/actions/runners \
  --jq '.runners[] | "\(.name): \(.status)"'

# From the RPi4 itself
ssh user@rpi4 "sudo systemctl status actions.runner.yoyonel-genesis-rs.genesis-rpi4"
```

### Restart the runner

```bash
ssh user@rpi4 "cd ~/actions-runner && sudo ./svc.sh stop && sudo ./svc.sh start"
```

### Update the runner

GitHub auto-updates runners in most cases. For manual update:

```bash
ssh user@rpi4 "cd ~/actions-runner && sudo ./svc.sh stop"
# Re-download and extract new version (same steps as initial install)
ssh user@rpi4 "cd ~/actions-runner && sudo ./svc.sh start"
```

### Runner is offline but RPi4 is reachable

1. Check systemd service: `sudo systemctl status actions.runner.*`
2. Check logs: `journalctl -u actions.runner.yoyonel-genesis-rs.genesis-rpi4 -n 50`
3. Restart: `sudo ./svc.sh stop && sudo ./svc.sh start`

### CI is stuck waiting for runner

This should not happen with the fallback mechanism. If it does:
1. Verify `check-rpi4` job ran and its output
2. Check that `vars.RPI4_RUNNER` is not set to `true` while runner is actually offline
3. Cancel the stuck workflow run: `gh run cancel <run-id>`

### RAM pressure on RPi4

The RPi4 also runs Prometheus + Grafana (~1.8 GB used). The runner itself uses ~50 MB.
Monitor with:

```bash
ssh user@rpi4 "free -h && echo --- && df -h /"
```

If RAM is tight, consider stopping Grafana during CI runs or increasing swap further.
