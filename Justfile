# Justfile for genesis-rs
# Organized by: Variables > Quality > Build > VM Provisioning > VM Boot/Deploy > E2E/CI

# ─── Variables ────────────────────────────────────────────────────────────────

TARGET        := "x86_64-unknown-linux-musl"
ARM_TARGET    := "aarch64-unknown-linux-musl"
E2E_DIR       := "tests/e2e"
E2E_KEY       := E2E_DIR / "e2e_key"
SSH_OPTS      := "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i " + E2E_KEY

DEBIAN_URL    := "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
ARCH_URL      := "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
RASPBIAN_URL  := "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2"

# ─── Quality ──────────────────────────────────────────────────────────────────

# Setup development environment (install QEMU, genisoimage, EFI firmware, Rust targets)
setup:
    scripts/setup-dev-env.sh

# Check prerequisites without installing
setup-check:
    scripts/setup-dev-env.sh --check-only

# Check the code compiles
check:
    cargo check

# Run all linters (Rust + CI workflows + GitHub Actions existence + shell)
lint: format-check lint-rust lint-ci check-actions lint-shell

# Lint Rust code (clippy, zero warnings)
lint-rust:
    cargo clippy -- -D warnings

# Lint GitHub Actions workflow YAML
lint-ci:
    actionlint .github/workflows/*.yml || echo "⚠️ actionlint non trouvé ou en erreur, ignoré."

# Verify GitHub Actions repositories exist
check-actions:
    @echo "🔍 Vérification de l'existence des GitHub Actions..."
    @grep "uses:" .github/workflows/*.yml | grep -v "./" | sed 's/.*uses: \(.*\)@.*/\1/' | sort -u | xargs -n 1 gh repo view --json nameWithOwner -q .nameWithOwner || (echo "❌ Une ou plusieurs actions sont introuvables !"; exit 1)
    @echo "✅ Toutes les actions sont valides."

# Lint shell scripts (shellcheck)
lint-shell:
    shellcheck scripts/*.sh

# Check dependency licenses, advisories, bans, and sources (cargo-deny)
lint-deps:
    cargo deny check all

# Format code
format:
    cargo fmt

# Check formatting without modifying files
format-check:
    cargo fmt --check

# Run unit and integration tests
test:
    cargo test

# Run tests with coverage reporting (requires cargo-tarpaulin)
coverage:
    cargo tarpaulin --skip-clean --out Stdout

# Generate Rustdoc
doc:
    cargo doc --no-deps
    @echo "✅ Documentation generated in target/doc/"

# Generate and serve Rustdoc locally on http://localhost:8085
doc-serve: doc
    @echo "Lancement du serveur de doc sur http://localhost:8085"
    python3 -m http.server --directory target/doc 8085

# Install Git pre-commit hook (runs `just lint` before each commit)
install-hooks:
    @echo "Installing pre-commit hook..."
    @printf '#!/bin/bash\n# genesis-rs pre-commit hook\nset -e\njust lint\n' > .git/hooks/pre-commit
    @chmod +x .git/hooks/pre-commit
    @echo "✅ Hook installed."

# ─── Build ────────────────────────────────────────────────────────────────────

# Build for the host architecture (static musl)
build target=TARGET:
    cargo build --release --target {{target}}

# Build ARM64 (auto-detects: native cross > Distrobox > podman/docker)
build-arm:
    scripts/build-arm.sh {{ARM_TARGET}}

# Build ARM64 natively (for CI runners with native aarch64)
build-arm-native target=ARM_TARGET:
    cargo build --release --target {{target}}

# Build .deb package (requires cargo-deb)
package-deb: (build TARGET)
    cargo deb --no-build --target {{TARGET}}
    @echo "✅ .deb package built in target/{{TARGET}}/debian/"

# ─── VM Provisioning ─────────────────────────────────────────────────────────

# Generate SSH key pair for E2E tests (idempotent)
provision-setup:
    scripts/provision-setup.sh {{E2E_DIR}}

# Provision all 3 Cloud VM images
provision-vms: provision-setup provision-debian provision-arch provision-raspbian
    @echo "✅ All VMs provisioned."

# Provision Debian Cloud VM
provision-debian: provision-setup
    scripts/provision-vm.sh debian "{{DEBIAN_URL}}"

# Provision Arch Linux Cloud VM
provision-arch: provision-setup
    scripts/provision-vm.sh arch "{{ARCH_URL}}"

# Provision Raspbian (ARM64) Cloud VM + EFI firmware
provision-raspbian: provision-setup
    scripts/provision-vm.sh raspbian "{{RASPBIAN_URL}}" --arm64

# ─── VM Boot & Deploy ────────────────────────────────────────────────────────

# Boot Debian VM (headless, port 22221)
boot-debian:
    scripts/boot-vm.sh debian 22221 {{E2E_DIR}}

# Boot Arch Linux VM (headless, port 22222)
boot-arch:
    scripts/boot-vm.sh arch 22222 {{E2E_DIR}}

# Boot Raspbian VM ARM64 (headless, port 22223)
boot-raspbian:
    scripts/boot-vm.sh raspbian 22223 {{E2E_DIR}} --arm64

# Deploy and run a command on Debian VM
deploy-debian cmd="bootstrap" target=TARGET:
    scp {{SSH_OPTS}} -P 22221 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
    ssh {{SSH_OPTS}} -p 22221 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Deploy and run a command on Arch Linux VM
deploy-arch cmd="bootstrap" target=TARGET:
    scp {{SSH_OPTS}} -P 22222 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
    ssh {{SSH_OPTS}} -p 22222 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Deploy and run a command on Raspbian VM (ARM64)
deploy-raspbian cmd="bootstrap" target=ARM_TARGET:
    scp {{SSH_OPTS}} -P 22223 target/{{target}}/release/genesis-rs genesis@localhost:/tmp/genesis-rs
    ssh {{SSH_OPTS}} -p 22223 genesis@localhost "chmod +x /tmp/genesis-rs && /tmp/genesis-rs {{cmd}}"

# Kill all background VMs (PID-based, safe)
clean-vms:
    scripts/clean-vms.sh {{E2E_DIR}}

# Show status of running VMs
status-vms:
    scripts/status-vms.sh {{E2E_DIR}}

# Bootstrap Debian and open interactive shell (build → boot → deploy → ssh)
try-debian reset="": (build TARGET)
    scripts/try-vm.sh debian 22221 {{TARGET}} {{E2E_DIR}} {{reset}}

# Bootstrap Arch and open interactive shell (build → boot → deploy → ssh)
try-arch reset="": (build TARGET)
    scripts/try-vm.sh arch 22222 {{TARGET}} {{E2E_DIR}} {{reset}}

# Bootstrap Raspbian ARM64 and open interactive shell (build → boot → deploy → ssh)
try-raspbian reset="": (build ARM_TARGET)
    scripts/try-vm.sh raspbian 22223 {{ARM_TARGET}} {{E2E_DIR}} {{reset}} --arm64

# SSH into a running Debian VM
ssh-debian:
    -ssh {{SSH_OPTS}} -p 22221 -t genesis@localhost

# SSH into a running Arch VM
ssh-arch:
    -ssh {{SSH_OPTS}} -p 22222 -t genesis@localhost

# SSH into a running Raspbian VM
ssh-raspbian:
    -ssh {{SSH_OPTS}} -p 22223 -t genesis@localhost

# Reset a single VM overlay to pristine state (idempotent boot)
reset-overlay os:
    scripts/reset-overlay.sh {{os}} {{E2E_DIR}}

# Reset ALL VM overlays to pristine state
reset-overlays:
    scripts/reset-overlay.sh all {{E2E_DIR}}

# ─── E2E Testing & CI ────────────────────────────────────────────────────────

# Wait for SSH on a specific port
wait-ssh PORT:
    scripts/wait-ssh.sh {{PORT}}

# Run E2E test cycle for one OS (boot -> deploy detect -> clean)
ci-test os PORT target skip_build="false":
    scripts/ci-test.sh {{os}} {{PORT}} {{target}} "{{skip_build}}"

# Run the full local CI suite (all 3 distros, sequential)
ci-local: build build-arm provision-vms
    @echo "=== STARTING LOCAL CI TEST SUITE ==="
    just clean-vms
    just ci-test debian 22221 {{TARGET}} true
    just ci-test arch 22222 {{TARGET}} true
    just ci-test raspbian 22223 {{ARM_TARGET}} true
    @echo "=== LOCAL CI TEST SUITE COMPLETED ==="

# Benchmark boot + bootstrap on a specific OS
benchmark os="debian" target=TARGET:
    scripts/benchmark.sh {{os}} {{target}} {{ARM_TARGET}}


