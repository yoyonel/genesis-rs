#!/usr/bin/env bash
# Boot a VM, deploy genesis-rs, run bootstrap, then open an interactive SSH shell.
# Ensures everything is in place: image provisioned, binary built, SSH ready.
# Usage: try-vm.sh <os> <port> <target> <e2e_dir> [--reset] [--arm64]
set -euo pipefail

OS="${1:?Usage: try-vm.sh <os> <port> <target> <e2e_dir> [--reset] [--arm64]}"
PORT="${2:?}"
TARGET="${3:?}"
E2E_DIR="${4:?}"

RESET=false
ARM64=""
shift 4
for arg in "$@"; do
    case "$arg" in
        --reset) RESET=true ;;
        --arm64) ARM64="--arm64" ;;
    esac
done

E2E_KEY="${E2E_DIR}/e2e_key"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${E2E_KEY}"
BINARY="target/${TARGET}/release/genesis-rs"

echo "═══════════════════════════════════════════════════════"
echo "  🧪 genesis-rs — try ${OS} (port ${PORT})"
echo "═══════════════════════════════════════════════════════"

# ─── 1. Check binary exists ──────────────────────────────────────────────────
if [ ! -f "${BINARY}" ]; then
    echo "❌ Binary not found: ${BINARY}"
    echo "   Run: just build" 
    if [ "${ARM64}" = "--arm64" ]; then
        echo "   Or:  just build-arm"
    fi
    exit 1
fi
echo "✅ Binary: ${BINARY}"

# ─── 2. Check VM image is provisioned ────────────────────────────────────────
BASE_IMAGE="${E2E_DIR}/${OS}.qcow2"
if [ ! -f "${BASE_IMAGE}" ]; then
    echo "❌ Base image not found: ${BASE_IMAGE}"
    echo "   Run: just provision-${OS}"
    exit 1
fi
echo "✅ Base image: ${BASE_IMAGE}"

# ─── 3. Check SSH key exists ─────────────────────────────────────────────────
if [ ! -f "${E2E_KEY}" ]; then
    echo "❌ SSH key not found: ${E2E_KEY}"
    echo "   Run: just provision-setup"
    exit 1
fi
echo "✅ SSH key: ${E2E_KEY}"

# ─── 4. Reset overlay (optional, clean state) ───────────────────────────────
if [ "${RESET}" = true ]; then
    echo "🔄 Resetting overlay to pristine state..."
    scripts/reset-overlay.sh "${OS}" "${E2E_DIR}"
else
    echo "⏩ Skipping overlay reset (use --reset for clean state)"
fi

# ─── 5. Boot VM ──────────────────────────────────────────────────────────────
echo "🚀 Booting ${OS} VM..."
scripts/boot-vm.sh "${OS}" "${PORT}" "${E2E_DIR}" ${ARM64}

# ─── 6. Wait for SSH ─────────────────────────────────────────────────────────
echo "⏳ Waiting for SSH to be ready..."
scripts/wait-ssh.sh "${PORT}"

# ─── 7. Deploy binary ────────────────────────────────────────────────────────
echo "📦 Deploying genesis-rs to VM..."
scp ${SSH_OPTS} -P "${PORT}" "${BINARY}" genesis@localhost:/tmp/genesis-rs
ssh ${SSH_OPTS} -p "${PORT}" genesis@localhost "chmod +x /tmp/genesis-rs"
echo "✅ Binary deployed to /tmp/genesis-rs"

# ─── 8. Run bootstrap ────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  🔧 Running: genesis-rs bootstrap"
echo "═══════════════════════════════════════════════════════"
echo ""
ssh ${SSH_OPTS} -p "${PORT}" genesis@localhost "/tmp/genesis-rs bootstrap" || true

# ─── 9. Interactive shell ─────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  🐚 Interactive shell on ${OS} (port ${PORT})"
echo "  genesis-rs is at /tmp/genesis-rs"
echo "  Type 'exit' to leave. VM stays running."
echo "  Stop VM later with: just clean-vms"
echo "═══════════════════════════════════════════════════════"
echo ""
ssh ${SSH_OPTS} -p "${PORT}" -t genesis@localhost || true
