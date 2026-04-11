#!/usr/bin/env bash
# Wait for SSH to become available on a given port, then wait for cloud-init to finish.
# Usage: wait-ssh.sh <port> [max_attempts] [interval_sec]
set -euo pipefail

PORT="${1:?Usage: wait-ssh.sh <port> [max_attempts] [interval_sec]}"
MAX_ATTEMPTS="${2:-300}"
INTERVAL="${3:-2}"
E2E_KEY="tests/e2e/e2e_key"
SSH_CMD="ssh -i ${E2E_KEY} -p ${PORT} genesis@localhost -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2"

echo "Waiting for SSH on port ${PORT} (max ${MAX_ATTEMPTS} attempts)..."
for i in $(seq 1 "${MAX_ATTEMPTS}"); do
    if ${SSH_CMD} echo "up" > /dev/null 2>&1; then
        echo "SSH up, waiting for cloud-init to finish..."
        ${SSH_CMD} "cloud-init status --wait > /dev/null 2>&1 || true"
        echo "SSH is ready!"
        exit 0
    fi
    printf "."
    sleep "${INTERVAL}"
done

echo ""
echo "❌ SSH timeout after ${MAX_ATTEMPTS} attempts on port ${PORT}"
exit 1
