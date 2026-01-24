#!/bin/bash
# Submit a job to the daemon queue
# Usage: ./submit-job.sh <command> [payload_json] [priority]
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"
COMMAND="${1:?Usage: $0 <command> [payload_json] [priority]}"
PAYLOAD="${2:-{}}"
PRIORITY="${3:-0}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

grpcurl -plaintext -unix "$SOCKET" \
    -d "{\"command\": \"$COMMAND\", \"payload\": $PAYLOAD, \"priority\": $PRIORITY}" \
    honeydew.Daemon/SubmitJob
