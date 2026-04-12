#!/usr/bin/env bash
# Run a full CI E2E test cycle for a specific OS.
# Usage: ci-test.sh <os> <port> <target> [skip_build]
set -euo pipefail

OS="${1:?Usage: ci-test.sh <os> <port> <target> [skip_build]}"
PORT="${2:?Usage: ci-test.sh <os> <port> <target> [skip_build]}"
TARGET="${3:?Usage: ci-test.sh <os> <port> <target> [skip_build]}"
SKIP_BUILD="${4:-false}"

if [ "${SKIP_BUILD}" != "true" ]; then
    just build "${TARGET}"
fi

# Reset overlay to ensure idempotent test run
scripts/reset-overlay.sh "${OS}"

START_BOOT=$(date +%s%3N)
just boot-"${OS}"
scripts/wait-ssh.sh "${PORT}"
END_BOOT=$(date +%s%3N)
BOOT_TIME=$((END_BOOT - START_BOOT))

START_DEPLOY=$(date +%s%3N)
just deploy-"${OS}" "detect" "${TARGET}"
END_DEPLOY=$(date +%s%3N)
DEPLOY_TIME=$((END_DEPLOY - START_DEPLOY))

just clean-vms

echo ""
echo "--- CI PERFORMANCE METRICS (${OS}) ---"
echo "Boot Time:   ${BOOT_TIME}ms"
echo "Deploy Time: ${DEPLOY_TIME}ms"
echo "Total E2E:   $((BOOT_TIME + DEPLOY_TIME))ms"
