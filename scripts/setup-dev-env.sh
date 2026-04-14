#!/usr/bin/env bash
# Setup the development environment for genesis-rs E2E testing.
# Installs all required system packages (QEMU, genisoimage, EFI firmware, musl toolchain).
#
# Supported host distros: Debian/Ubuntu, Fedora/Bazzite, Arch Linux
# Usage: scripts/setup-dev-env.sh [--check-only]
set -euo pipefail

CHECK_ONLY="${1:-}"
ERRORS=0

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
miss() { echo -e "  ${RED}❌${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
info() { echo -e "\n${YELLOW}▶${NC} $1"; }

# ─── Detect host distro ──────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "${ID:-}" in
            debian|ubuntu|linuxmint|pop) echo "debian" ;;
            fedora|bazzite|nobara)       echo "fedora" ;;
            arch|manjaro|endeavouros)    echo "arch" ;;
            *)
                # Fallback: check ID_LIKE
                case "${ID_LIKE:-}" in
                    *debian*) echo "debian" ;;
                    *fedora*) echo "fedora" ;;
                    *arch*)   echo "arch" ;;
                    *)        echo "unknown" ;;
                esac
                ;;
        esac
    else
        echo "unknown"
    fi
}

# ─── Check a binary exists ───────────────────────────────────────────────────
check_bin() {
    local name="$1"
    local pkg="${2:-$1}"
    if command -v "$name" &>/dev/null; then
        ok "$name ($(command -v "$name"))"
    else
        miss "$name — install package: $pkg"
    fi
}

# ─── Check a file exists ─────────────────────────────────────────────────────
check_file() {
    local label="$1"
    shift
    for f in "$@"; do
        if [ -f "$f" ]; then
            ok "$label ($f)"
            return 0
        fi
    done
    miss "$label — not found"
    return 0  # don't abort under set -e; ERRORS counter tracks failures
}

# ─── Package lists per distro ────────────────────────────────────────────────
DEBIAN_PKGS=(
    qemu-system-x86
    qemu-system-arm
    qemu-utils
    genisoimage
    qemu-efi-aarch64
    wget
    openssh-client
    musl-tools
    gcc-aarch64-linux-gnu
)

FEDORA_PKGS=(
    qemu-system-x86-core
    qemu-system-aarch64-core
    qemu-img
    genisoimage
    edk2-aarch64
    wget
    openssh-clients
    musl-gcc
    gcc-aarch64-linux-gnu
)

ARCH_PKGS=(
    qemu-system-x86
    qemu-system-aarch64
    qemu-img
    cdrtools
    edk2-aarch64
    wget
    openssh
    musl
    aarch64-linux-gnu-gcc
)

# ─── Main ─────────────────────────────────────────────────────────────────────
DISTRO=$(detect_distro)
echo "═══════════════════════════════════════════════════════════"
echo "  genesis-rs Development Environment Setup"
echo "  Host: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "  Distro family: ${DISTRO}"
echo "═══════════════════════════════════════════════════════════"

info "Checking required tools..."
check_bin qemu-system-x86_64 "qemu-system-x86"
check_bin qemu-system-aarch64 "qemu-system-arm"
check_bin qemu-img "qemu-utils"
check_bin genisoimage "genisoimage"
check_bin mkisofs "genisoimage"  # alternative name
check_bin wget
check_bin ssh "openssh-client"
check_bin just "just (https://just.systems)"
check_bin cargo "rustup (https://rustup.rs)"

info "Checking Rust targets..."
if command -v rustup &>/dev/null; then
    if rustup target list --installed 2>/dev/null | grep -q "x86_64-unknown-linux-musl"; then
        ok "x86_64-unknown-linux-musl target"
    else
        miss "x86_64-unknown-linux-musl target — run: rustup target add x86_64-unknown-linux-musl"
    fi
    if rustup target list --installed 2>/dev/null | grep -q "aarch64-unknown-linux-musl"; then
        ok "aarch64-unknown-linux-musl target"
    else
        miss "aarch64-unknown-linux-musl target — run: rustup target add aarch64-unknown-linux-musl"
    fi
else
    miss "rustup not found"
fi

info "Checking cross-compilation linker..."
check_bin aarch64-linux-gnu-gcc "gcc-aarch64-linux-gnu"

info "Checking musl linker..."
check_bin musl-gcc "musl-tools"

info "Checking AArch64 EFI firmware..."
check_file "QEMU AArch64 EFI firmware" \
    "/usr/share/AAVMF/AAVMF_CODE.fd" \
    "/usr/share/edk2/aarch64/QEMU_EFI.fd" \
    "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"

info "Checking KVM hardware acceleration..."
check_kvm() {
    local cpu_vendor=""
    local kvm_module=""
    local has_virt_flags=false

    # 1. Detect CPU virtualization capability
    if grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
        has_virt_flags=true
        if grep -q 'vmx' /proc/cpuinfo 2>/dev/null; then
            cpu_vendor="Intel"
            kvm_module="kvm_intel"
        else
            cpu_vendor="AMD"
            kvm_module="kvm_amd"
        fi
    fi

    if ! $has_virt_flags; then
        warn "CPU does NOT support hardware virtualization (no vmx/svm flags)"
        echo ""
        echo -e "    ${YELLOW}Your CPU lacks VT-x (Intel) or AMD-V support.${NC}"
        echo "    VMs will run in TCG mode (pure software emulation)."
        echo "    This is 10-20x slower than KVM. Expected boot times: ~4-5 min instead of ~20s."
        echo ""
        echo "    If you're inside a VM yourself, enable nested virtualization on the host."
        return
    fi

    # 2. Check if KVM module is loaded
    local lsmod_out
    lsmod_out="$(lsmod 2>/dev/null)"
    if ! echo "${lsmod_out}" | grep -q "^kvm "; then
        miss "KVM module not loaded (CPU: ${cpu_vendor}, module: ${kvm_module})"
        echo ""
        echo -e "    ${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "    ${RED}║  CRITICAL: KVM is NOT active — VMs are running 10-20x slower!  ║${NC}"
        echo -e "    ${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "    Your ${cpu_vendor} CPU supports hardware virtualization, but the"
        echo "    kernel module '${kvm_module}' is not loaded."
        echo ""
        echo -e "    ${GREEN}To fix NOW (until next reboot):${NC}"
        echo "      sudo modprobe ${kvm_module}"
        echo ""
        echo -e "    ${GREEN}To fix PERMANENTLY (survives reboot):${NC}"
        echo "      echo '${kvm_module}' | sudo tee /etc/modules-load.d/kvm.conf"
        echo "      sudo modprobe ${kvm_module}"
        echo ""
        echo -e "    ${YELLOW}Impact:${NC} Without KVM, a VM boot takes ~4-5 min vs ~20s with KVM."
        echo "    Bootstrap (pacman -Syu + packages) takes ~10 min vs ~30s."
        return
    fi

    # 3. Check /dev/kvm exists and is accessible
    if [ ! -e /dev/kvm ]; then
        miss "/dev/kvm device missing (module loaded but device not created)"
        echo "    Try: sudo modprobe ${kvm_module}"
        return
    fi

    if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        miss "/dev/kvm not accessible by current user"
        echo ""
        echo "    /dev/kvm exists but you don't have read+write permission."
        echo ""
        echo -e "    ${GREEN}Fix:${NC} Add yourself to the 'kvm' group:"
        echo "      sudo usermod -aG kvm \$(whoami)"
        echo "      newgrp kvm   # or log out and back in"
        echo ""
        echo "    Current permissions: $(stat -c '%A %U %G' /dev/kvm 2>/dev/null)"
        echo "    Your groups: $(groups)"
        return
    fi

    # All good!
    ok "KVM active (${cpu_vendor} ${kvm_module}, /dev/kvm accessible)"
    echo -e "    VMs will use hardware acceleration — ${GREEN}optimal performance${NC}."
}
check_kvm

info "Checking optional tools..."
if command -v actionlint &>/dev/null; then
    ok "actionlint"
else
    warn "actionlint not found (optional, for CI workflow linting)"
fi
if command -v gh &>/dev/null; then
    ok "gh CLI"
else
    warn "gh CLI not found (optional, for check-actions recipe)"
fi

# ─── Install if needed ───────────────────────────────────────────────────────
if [ "${CHECK_ONLY}" = "--check-only" ]; then
    echo ""
    if [ "${ERRORS}" -gt 0 ]; then
        echo -e "${RED}${ERRORS} missing dependencies.${NC} Run without --check-only to install."
        exit 1
    else
        echo -e "${GREEN}All dependencies satisfied!${NC}"
        exit 0
    fi
fi

if [ "${ERRORS}" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All dependencies already satisfied! Nothing to install.${NC}"
else
    echo ""
    info "Installing missing packages..."

    case "${DISTRO}" in
        debian)
            echo "Running: sudo apt-get install -y ${DEBIAN_PKGS[*]}"
            sudo apt-get update -qq
            sudo apt-get install -y "${DEBIAN_PKGS[@]}"
            ;;
        fedora)
            echo "Running: sudo dnf install -y ${FEDORA_PKGS[*]}"
            sudo dnf install -y "${FEDORA_PKGS[@]}"
            ;;
        arch)
            echo "Running: sudo pacman -S --noconfirm ${ARCH_PKGS[*]}"
            sudo pacman -S --noconfirm "${ARCH_PKGS[@]}"
            ;;
        *)
            echo -e "${RED}Unknown distro '${DISTRO}'. Manual install required:${NC}"
            echo "  - qemu-system-x86_64, qemu-system-aarch64, qemu-img"
            echo "  - genisoimage (or mkisofs)"
            echo "  - AArch64 EFI firmware (edk2/AAVMF)"
            echo "  - musl-tools, gcc-aarch64-linux-gnu"
            exit 1
            ;;
    esac

    info "Installing Rust targets..."
    rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl

    info "Re-checking after install..."
    exec "$0" --check-only
fi

# ─── Final setup steps ───────────────────────────────────────────────────────
info "Running project setup..."

# Install git hooks
just install-hooks 2>/dev/null || true

# Provision SSH keys (idempotent)
just provision-setup 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✅ Development environment ready!${NC}"
echo ""
echo "  Quick start:"
echo "    just provision-vms    # Download cloud images (~1-2 GB)"
echo "    just boot-debian      # Boot a Debian VM"
echo "    just build            # Build x86_64 binary"
echo "    just deploy-debian    # Deploy & run on VM"
echo "═══════════════════════════════════════════════════════════"
