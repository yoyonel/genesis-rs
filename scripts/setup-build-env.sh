#!/bin/bash
set -e

BOX_NAME="genesis-lab"

if ! distrobox list | grep -q "${BOX_NAME}"; then
    echo "Creating distrobox ${BOX_NAME}..."
    distrobox create --name "${BOX_NAME}" --image fedora:42 --yes
fi

echo "Installing toolchain in ${BOX_NAME}..."
distrobox enter "${BOX_NAME}" -- bash -c "
    sudo dnf install -y gcc-aarch64-linux-gnu rustup
    if [ ! -f \$HOME/.cargo/bin/rustup ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
    fi
    source \$HOME/.cargo/env
    rustup target add aarch64-unknown-linux-musl
"

echo "Build environment ready in ${BOX_NAME}."
