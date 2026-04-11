#!/usr/bin/env bash
# Boot a QEMU VM with KVM if accessible, TCG fallback otherwise.
# Usage: boot-vm.sh <os> <port> <e2e_dir> [--arm64]
set -euo pipefail

OS="${1:?Usage: boot-vm.sh <os> <port> <e2e_dir> [--arm64]}"
PORT="${2:?}"
E2E_DIR="${3:?}"
ARM64="${4:-}"

if [ "${ARM64}" = "--arm64" ]; then
    # ARM64: always TCG (no KVM on x86 host for aarch64)
    qemu-system-aarch64 -m 2G -smp 2 -daemonize -M virt -cpu max -display none \
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
    fi

    qemu-system-x86_64 -m 2G -smp 2 -daemonize -cpu "${CPU}" -display none \
        -accel "${ACCEL}" \
        -device virtio-net-pci,netdev=net0 -netdev user,id=net0,hostfwd=tcp::"${PORT}"-:22 \
        -drive file="${E2E_DIR}/${OS}-test.qcow2",format=qcow2,if=virtio,cache=unsafe \
        -drive file="${E2E_DIR}/cloud-init/seed.iso",format=raw,if=virtio,readonly=on \
        -device virtio-rng-pci
    echo "${OS} booted (Port ${PORT}, accel=${ACCEL})."
fi
