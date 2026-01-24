#!/bin/bash
# List all jobs in the queue
# Usage: ./list-jobs.sh [status_filter]
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"
STATUS="${1:-}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

if [[ -n "$STATUS" ]]; then
    grpcurl -plaintext -unix "$SOCKET" \
        -d "{\"status\": \"$STATUS\"}" \
        honeydew.Daemon/ListJobs
else
    grpcurl -plaintext -unix "$SOCKET" honeydew.Daemon/ListJobs
fi
