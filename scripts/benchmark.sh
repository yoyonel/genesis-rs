#!/usr/bin/env bash
# Run a benchmark on a specific OS (boot + bootstrap + metrics).
# Usage: benchmark.sh <os> <target> <arm_target>
set -euo pipefail

OS="${1:?Usage: benchmark.sh <os> <target> <arm_target>}"
TARGET="${2:?}"
ARM_TARGET="${3:?}"

# Resolve port and target for OS
case "${OS}" in
    debian)   OS_PORT=22221; OS_TARGET="${TARGET}" ;;
    arch)     OS_PORT=22222; OS_TARGET="${TARGET}" ;;
    raspbian) OS_PORT=22223; OS_TARGET="${ARM_TARGET}" ;;
    *)        echo "Unsupported OS: ${OS}"; exit 1 ;;
esac

# Kill any running VMs
killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true

START_BOOT=$(date +%s%3N)
just boot-"${OS}"

printf "Waiting for SSH on port %s..." "${OS_PORT}"
END_BOOT=""
for _ in $(seq 1 120); do
    if ssh -i tests/e2e/e2e_key -p "${OS_PORT}" genesis@localhost \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=1 \
        echo "up" > /dev/null 2>&1; then
        END_BOOT=$(date +%s%3N)
        echo " Ready."
        break
    fi
    printf "."
    sleep 2
done

if [ -z "${END_BOOT}" ]; then
    echo " Boot failed!"
    exit 1
fi

BOOT_TIME=$((END_BOOT - START_BOOT))

START_DEPLOY=$(date +%s%3N)
just deploy-"${OS}" "bootstrap" "${OS_TARGET}"
END_DEPLOY=$(date +%s%3N)
DEPLOY_TIME=$((END_DEPLOY - START_DEPLOY))

killall qemu-system-x86_64 qemu-system-aarch64 2>/dev/null || true

echo "--- BENCHMARK RESULTS (${OS}) ---"
echo "Boot Time:   ${BOOT_TIME}ms"
echo "Deploy Time: ${DEPLOY_TIME}ms"
echo "Total E2E:   $((BOOT_TIME + DEPLOY_TIME))ms"
