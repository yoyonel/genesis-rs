#!/usr/bin/env bash
# Build ARM64 binary using the best available method:
# 1. Native cross-compilation (if aarch64-linux-gnu-gcc + musl target available)
# 2. Distrobox container (Bazzite/Fedora with genesis-lab container)
# 3. Podman/Docker container (generic fallback)
set -euo pipefail

ARM_TARGET="${1:-aarch64-unknown-linux-musl}"

echo "▶ Building ARM64 target: ${ARM_TARGET}"

# ─── Method 1: Native cross-compilation ──────────────────────────────────────
if command -v aarch64-linux-gnu-gcc &>/dev/null \
    && rustup target list --installed 2>/dev/null | grep -q "${ARM_TARGET}"; then
    echo "  Using native cross-compilation (aarch64-linux-gnu-gcc found)"
    cargo build --release --target "${ARM_TARGET}"
    echo "✅ ARM64 build complete (native cross)"
    exit 0
fi

# ─── Method 2: Distrobox (Bazzite/Fedora) ────────────────────────────────────
if command -v distrobox &>/dev/null \
    && distrobox list 2>/dev/null | grep -q "genesis-lab"; then
    echo "  Using Distrobox container 'genesis-lab'"
    distrobox enter genesis-lab -- cargo build --release --target "${ARM_TARGET}"
    echo "✅ ARM64 build complete (Distrobox)"
    exit 0
fi

# ─── Method 3: Podman/Docker container ───────────────────────────────────────
CONTAINER_RT=""
if command -v podman &>/dev/null; then
    CONTAINER_RT="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_RT="docker"
fi

if [ -n "${CONTAINER_RT}" ]; then
    IMAGE="ghcr.io/rust-cross/rust-musl-cross:aarch64-musl"
    echo "  Using ${CONTAINER_RT} with image ${IMAGE}"
    ${CONTAINER_RT} run --rm \
        -v "${PWD}":/home/rust/src:Z \
        -w /home/rust/src \
        "${IMAGE}" \
        cargo build --release --target "${ARM_TARGET}"
    echo "✅ ARM64 build complete (${CONTAINER_RT})"
    exit 0
fi

echo "❌ No cross-compilation method available!"
echo "   Install one of:"
echo "   - aarch64-linux-gnu-gcc + rustup target add ${ARM_TARGET}"
echo "   - distrobox with genesis-lab container"
echo "   - podman or docker"
exit 1
