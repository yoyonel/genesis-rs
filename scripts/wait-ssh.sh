#!/usr/bin/env bash
# Wait for SSH to become available on a given port, then wait for cloud-init to finish.
# Handles sshd restarts during cloud-init with retry logic.
# Usage: wait-ssh.sh <port> [max_attempts] [interval_sec]
# shellcheck disable=SC2086  # SSH_OPTS intentionally word-split (multiple args)
set -euo pipefail

PORT="${1:?Usage: wait-ssh.sh <port> [max_attempts] [interval_sec]}"
MAX_ATTEMPTS="${2:-300}"
INTERVAL="${3:-2}"
E2E_KEY="tests/e2e/e2e_key"
SSH_OPTS="-i ${E2E_KEY} -p ${PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2"

echo "Waiting for SSH on port ${PORT} (max ${MAX_ATTEMPTS} attempts)..."
for _i in $(seq 1 "${MAX_ATTEMPTS}"); do
    if ssh ${SSH_OPTS} genesis@localhost echo "up" > /dev/null 2>&1; then
        echo "SSH up, waiting for cloud-init to finish..."
        # cloud-init may restart sshd, retry the wait command if connection drops
        for retry in $(seq 1 5); do
            if ssh ${SSH_OPTS} -o ConnectTimeout=10 -o ServerAliveInterval=5 \
                genesis@localhost "cloud-init status --wait > /dev/null 2>&1 || true" 2>/dev/null; then
                echo "SSH is ready!"
                exit 0
            fi
            echo "  SSH dropped during cloud-init wait, retrying (${retry}/5)..."
            sleep 5
        done
        # If all retries fail, last check: is SSH up now?
        if ssh ${SSH_OPTS} genesis@localhost echo "up" > /dev/null 2>&1; then
            echo "SSH is ready (cloud-init wait skipped)!"
            exit 0
        fi
        echo "❌ SSH unstable after cloud-init retries"
        exit 1
    fi
    printf "."
    sleep "${INTERVAL}"
done

echo ""
echo "❌ SSH timeout after ${MAX_ATTEMPTS} attempts on port ${PORT}"
exit 1
