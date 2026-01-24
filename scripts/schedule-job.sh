#!/bin/bash
# Schedule a recurring job
# Usage: ./schedule-job.sh <name> <cron_expr> <command> [payload_json]
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"
NAME="${1:?Usage: $0 <name> <cron_expr> <command> [payload_json]}"
CRON_EXPR="${2:?Usage: $0 <name> <cron_expr> <command> [payload_json]}"
COMMAND="${3:?Usage: $0 <name> <cron_expr> <command> [payload_json]}"
PAYLOAD="${4:-{}}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

grpcurl -plaintext -unix "$SOCKET" \
    -d "{\"name\": \"$NAME\", \"cron_expr\": \"$CRON_EXPR\", \"command\": \"$COMMAND\", \"payload\": $PAYLOAD}" \
    honeydew.Daemon/ScheduleJob
