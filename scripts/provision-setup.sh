#!/usr/bin/env bash
# Setup SSH keys and Cloud-Init user-data for E2E tests.
# Usage: provision-setup.sh <e2e_dir>
set -euo pipefail

E2E_DIR="${1:?Usage: provision-setup.sh <e2e_dir>}"
E2E_KEY="${E2E_DIR}/e2e_key"
CLOUD_INIT_DIR="${E2E_DIR}/cloud-init"

mkdir -p "${CLOUD_INIT_DIR}"

# Generate SSH key pair (idempotent)
if [ ! -f "${E2E_KEY}" ]; then
    echo "Generating SSH key pair..."
    ssh-keygen -t ed25519 -N "" -f "${E2E_KEY}" -C "e2e@genesis" > /dev/null
fi

# Inject public key into user-data (idempotent — handles both placeholder and existing key)
PUB_KEY=$(cat "${E2E_KEY}.pub")
# Replace placeholder if present (fresh clone)
sed -i "s|__GENESIS_SSH_KEY__|${PUB_KEY}|" "${CLOUD_INIT_DIR}/user-data" 2>/dev/null || true
# Replace any existing ssh key (CI regenerates keys each run)
sed -i "s|      - ssh-ed25519 .*|      - ${PUB_KEY}|" "${CLOUD_INIT_DIR}/user-data" 2>/dev/null || true

echo "✅ SSH keys and Cloud-Init ready."
