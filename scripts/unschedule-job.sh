#!/bin/bash
# Remove a scheduled job by ID
# Usage: ./unschedule-job.sh <schedule_id>
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"
SCHEDULE_ID="${1:?Usage: $0 <schedule_id>}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

grpcurl -plaintext -unix "$SOCKET" \
    -d "{\"schedule_id\": \"$SCHEDULE_ID\"}" \
    honeydew.Daemon/UnscheduleJob
