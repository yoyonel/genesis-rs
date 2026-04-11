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

# Auto-detect KVM: use hardware accel if /dev/kvm exists, else fall back to TCG
ACCEL_X86     := if path_exists("/dev/kvm") == "true" { "kvm" } else { "tcg,thread=multi" }
CPU_X86       := if path_exists("/dev/kvm") == "true" { "host" } else { "max" }

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

# Run all linters (Rust + CI workflows + GitHub Actions existence)
lint: lint-rust lint-ci check-actions

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

# Format code
format:
    cargo fmt

# Check formatting without modifying files
format-check:
    cargo fmt --check

# Run unit and integration tests
test:
    cargo test

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
    qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu {{CPU_X86}} -display none \
        -accel {{ACCEL_X86}} \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22221-:22 \
        -drive file={{E2E_DIR}}/debian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
        -drive file={{E2E_DIR}}/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    @echo "Debian booted (Port 22221, accel={{ACCEL_X86}})."

# Boot Arch Linux VM (headless, port 22222)
boot-arch:
    qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu {{CPU_X86}} -display none \
        -accel {{ACCEL_X86}} \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22222-:22 \
        -drive file={{E2E_DIR}}/arch-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
        -drive file={{E2E_DIR}}/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    @echo "Arch Linux booted (Port 22222, accel={{ACCEL_X86}})."

# Boot Raspbian VM ARM64 (headless, port 22223)
boot-raspbian:
    qemu-system-aarch64 -m 2G -smp 2 -daemonize -M virt -cpu max -display none \
        -accel tcg,thread=multi \
        -drive if=pflash,format=raw,file={{E2E_DIR}}/EFI_CODE.fd,readonly=on \
        -drive if=pflash,format=raw,file={{E2E_DIR}}/EFI_VARS.fd \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::22223-:22 \
        -drive file={{E2E_DIR}}/raspbian-test.qcow2,format=qcow2,if=virtio,cache=unsafe \
        -drive file={{E2E_DIR}}/cloud-init/seed.iso,format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    @echo "Raspbian (ARM64) booted (Port 22223)."

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

# Kill all background VMs
clean-vms:
    killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true
    @echo "All VMs terminated."

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


