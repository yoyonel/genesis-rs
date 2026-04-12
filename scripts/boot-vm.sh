#!/usr/bin/env bash
# Boot a QEMU VM with KVM if accessible, TCG fallback otherwise.
# Usage: boot-vm.sh <os> <port> <e2e_dir> [--arm64]
set -euo pipefail

OS="${1:?Usage: boot-vm.sh <os> <port> <e2e_dir> [--arm64]}"
PORT="${2:?}"
E2E_DIR="${3:?}"
ARM64="${4:-}"

PID_DIR="${E2E_DIR}/pids"
mkdir -p "${PID_DIR}"
PID_FILE="${PID_DIR}/${OS}.pid"

# Kill any existing VM for this OS
if [ -f "${PID_FILE}" ]; then
    OLD_PID=$(cat "${PID_FILE}")
    if kill -0 "${OLD_PID}" 2>/dev/null; then
        echo "Stopping existing ${OS} VM (PID ${OLD_PID})..."
        kill "${OLD_PID}" 2>/dev/null || true
        sleep 1
    fi
    rm -f "${PID_FILE}"
fi

if [ "${ARM64}" = "--arm64" ]; then
    # ARM64: always TCG (no KVM on x86 host for aarch64)
    qemu-system-aarch64 -m 2G -smp 2 -daemonize -M virt -cpu max -display none \
        -pidfile "${PID_FILE}" \
        -accel tcg,thread=multi \
        -drive if=pflash,format=raw,file="${E2E_DIR}/EFI_CODE.fd",readonly=on \
        -drive if=pflash,format=raw,file="${E2E_DIR}/EFI_VARS.fd" \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::"${PORT}"-:22 \
        -drive file="${E2E_DIR}/${OS}-test.qcow2",format=qcow2,if=virtio,cache=unsafe \
        -drive file="${E2E_DIR}/cloud-init/seed.iso",format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    echo "${OS} (ARM64) booted (Port ${PORT}, accel=tcg)."
else
    # x86_64: try KVM, fall back to TCG
    ACCEL="tcg,thread=multi"
    CPU="max"
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        ACCEL="kvm"
        CPU="host"
    else
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo "│  ⚠️  KVM unavailable — falling back to TCG (software emulation) │"
        echo "│  Boot will be 10-20x slower. Fix: sudo modprobe kvm_intel      │"
        echo "│  Permanent fix: run 'just setup' for detailed instructions.     │"
        echo "└─────────────────────────────────────────────────────────────────┘"
    fi

    qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu "${CPU}" -display none \
        -pidfile "${PID_FILE}" \
        -accel "${ACCEL}" \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::"${PORT}"-:22 \
        -drive file="${E2E_DIR}/${OS}-test.qcow2",format=qcow2,if=virtio,cache=unsafe \
        -drive file="${E2E_DIR}/cloud-init/seed.iso",format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    echo "${OS} booted (Port ${PORT}, accel=${ACCEL})."
fi
