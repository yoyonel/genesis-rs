#!/usr/bin/env bash
# Provision a Cloud VM image for E2E testing.
# Usage: provision-vm.sh <os> <image_url> [--arm64]
set -euo pipefail

OS="${1:?Usage: provision-vm.sh <os> <image_url> [--arm64]}"
IMAGE_URL="${2:?Usage: provision-vm.sh <os> <image_url> [--arm64]}"
ARM64="${3:-}"

E2E_DIR="tests/e2e"
CLOUD_INIT_DIR="${E2E_DIR}/cloud-init"

echo "Provisioning ${OS} Cloud VM..."

# Download base image if missing
if [ ! -f "${E2E_DIR}/${OS}.qcow2" ]; then
    echo "Downloading ${OS} image..."
    wget -q -c -O "${E2E_DIR}/${OS}.qcow2" "${IMAGE_URL}"
fi

# Create overlay image (copy-on-write)
qemu-img create -f qcow2 -F qcow2 -b "${OS}.qcow2" "${E2E_DIR}/${OS}-test.qcow2" || true

# Generate Cloud-Init seed ISO
mkisofs -output "${CLOUD_INIT_DIR}/seed.iso" -volid cidata -joliet -rock \
    "${CLOUD_INIT_DIR}/user-data" "${CLOUD_INIT_DIR}/meta-data"

# ARM64-specific: prepare EFI firmware
if [ "${ARM64}" = "--arm64" ]; then
    echo "Preparing AArch64 EFI firmware..."
    dd if=/dev/zero of="${E2E_DIR}/EFI_CODE.fd" bs=1M count=64 status=none

    EFI_PATH=""
    for p in \
        "/usr/share/AAVMF/AAVMF_CODE.fd" \
        "/usr/share/edk2/aarch64/QEMU_EFI.fd" \
        "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"; do
        if [ -f "$p" ]; then EFI_PATH="$p"; break; fi
    done

    if [ -z "$EFI_PATH" ]; then
        echo "❌ Error: QEMU AArch64 EFI firmware not found!"
        exit 1
    fi

    dd if="$EFI_PATH" of="${E2E_DIR}/EFI_CODE.fd" conv=notrunc status=none
    dd if=/dev/zero of="${E2E_DIR}/EFI_VARS.fd" bs=1M count=64 status=none
fi

echo "✅ ${OS} provisioned."
