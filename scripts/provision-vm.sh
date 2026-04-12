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

# --- Checksum verification helpers ---

verify_debian_checksum() {
    local image_path="$1"
    local image_url="$2"
    local base_url filename sha512sums_url expected_line

    base_url="${image_url%/*}"
    filename="${image_url##*/}"
    sha512sums_url="${base_url}/SHA512SUMS"

    echo "⬇️  Downloading SHA512SUMS from ${sha512sums_url}..."
    if ! wget -q -O "${image_path}.SHA512SUMS" "${sha512sums_url}"; then
        echo "⚠️  Could not download SHA512SUMS — skipping verification"
        return 0
    fi

    expected_line=$(grep "${filename}" "${image_path}.SHA512SUMS" || true)
    rm -f "${image_path}.SHA512SUMS"

    if [ -z "$expected_line" ]; then
        echo "⚠️  Filename '${filename}' not found in SHA512SUMS — skipping verification"
        return 0
    fi

    echo "🔍 Verifying SHA-512 checksum..."
    expected_hash=$(echo "$expected_line" | awk '{print $1}')
    actual_hash=$(sha512sum "$image_path" | awk '{print $1}')

    if [ "$expected_hash" != "$actual_hash" ]; then
        echo "❌ Checksum mismatch for ${filename}!"
        echo "   Expected: ${expected_hash}"
        echo "   Got:      ${actual_hash}"
        rm -f "$image_path"
        exit 1
    fi
    echo "✅ SHA-512 checksum verified."
}

verify_arch_checksum() {
    local image_path="$1"
    local image_url="$2"
    local sha256_url="${image_url}.SHA256"

    echo "⬇️  Downloading checksum from ${sha256_url}..."
    if ! wget -q -O "${image_path}.SHA256" "${sha256_url}"; then
        echo "⚠️  Could not download .SHA256 — skipping verification"
        return 0
    fi

    echo "🔍 Verifying SHA-256 checksum..."
    expected_hash=$(awk '{print $1}' "${image_path}.SHA256")
    actual_hash=$(sha256sum "$image_path" | awk '{print $1}')
    rm -f "${image_path}.SHA256"

    if [ "$expected_hash" != "$actual_hash" ]; then
        echo "❌ Checksum mismatch!"
        echo "   Expected: ${expected_hash}"
        echo "   Got:      ${actual_hash}"
        rm -f "$image_path"
        exit 1
    fi
    echo "✅ SHA-256 checksum verified."
}

verify_checksum() {
    local image_path="$1"
    local image_url="$2"

    if [[ "$image_url" == *"cloud.debian.org"* ]]; then
        verify_debian_checksum "$image_path" "$image_url"
    elif [[ "$image_url" == *"pkgbuild.com"* ]]; then
        verify_arch_checksum "$image_path" "$image_url"
    else
        echo "⚠️  Unknown image source — skipping checksum verification"
    fi
}

# --- Main provisioning ---

# Download base image if missing
if [ ! -f "${E2E_DIR}/${OS}.qcow2" ]; then
    echo "Downloading ${OS} image..."
    wget -q -c -O "${E2E_DIR}/${OS}.qcow2" "${IMAGE_URL}"
    verify_checksum "${E2E_DIR}/${OS}.qcow2" "${IMAGE_URL}"
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
