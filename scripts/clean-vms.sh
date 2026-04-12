#!/usr/bin/env bash
# Stop all tracked QEMU VMs using PID files.
# Usage: clean-vms.sh <e2e_dir>
set -euo pipefail

E2E_DIR="${1:?Usage: clean-vms.sh <e2e_dir>}"
PID_DIR="${E2E_DIR}/pids"

for pidfile in "${PID_DIR}"/*.pid; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile")
    os=$(basename "$pidfile" .pid)
    if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping $os VM (PID $pid)..."
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
done

echo "All VMs terminated."
