#!/usr/bin/env bash
# Show status of tracked QEMU VMs.
# Usage: status-vms.sh <e2e_dir>
set -euo pipefail

E2E_DIR="${1:?Usage: status-vms.sh <e2e_dir>}"
PID_DIR="${E2E_DIR}/pids"

echo "=== VM Status ==="

found=false
for pidfile in "${PID_DIR}"/*.pid; do
    [ -f "$pidfile" ] || continue
    found=true
    pid=$(cat "$pidfile")
    os=$(basename "$pidfile" .pid)
    if kill -0 "$pid" 2>/dev/null; then
        echo "  ✅ $os — running (PID $pid)"
    else
        echo "  ❌ $os — stale PID file (PID $pid)"
        rm -f "$pidfile"
    fi
done

if [ "$found" = false ]; then
    echo "No VMs tracked."
fi
