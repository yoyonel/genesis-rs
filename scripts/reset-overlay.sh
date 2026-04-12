#!/usr/bin/env bash
# Reset a VM overlay to pristine state (fresh copy-on-write from base image).
# This ensures idempotent VM boots by discarding all previous writes.
# Usage: reset-overlay.sh <os> [e2e_dir]
set -euo pipefail

OS="${1:?Usage: reset-overlay.sh <os|all> [e2e_dir]}"
E2E_DIR="${2:-tests/e2e}"

reset_one() {
    local os="$1"
    local base="${E2E_DIR}/${os}.qcow2"
    local overlay="${E2E_DIR}/${os}-test.qcow2"

    if [ ! -f "${base}" ]; then
        echo "❌ Base image not found: ${base} — run 'just provision-${os}' first."
        return 1
    fi

    if [ -f "${overlay}" ]; then
        local old_size
        old_size="$(du -h "${overlay}" | cut -f1)"
        rm "${overlay}"
        echo "  Removed dirty overlay (${old_size} delta)."
    fi

    qemu-img create -f qcow2 -F qcow2 -b "${os}.qcow2" "${overlay}" > /dev/null
    echo "  ✅ ${os}-test.qcow2 reset (clean overlay, 0 delta)."
}

if [ "${OS}" = "all" ]; then
    echo "Resetting all VM overlays..."
    for os in debian arch raspbian; do
        if [ -f "${E2E_DIR}/${os}.qcow2" ]; then
            reset_one "${os}"
        fi
    done
    echo "✅ All overlays reset."
else
    echo "Resetting ${OS} overlay..."
    reset_one "${OS}"
fi
