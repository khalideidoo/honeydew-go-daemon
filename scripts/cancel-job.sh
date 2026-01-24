#!/bin/bash
# Cancel a job by ID
# Usage: ./cancel-job.sh <job_id>
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"
JOB_ID="${1:?Usage: $0 <job_id>}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

grpcurl -plaintext -unix "$SOCKET" \
    -d "{\"job_id\": \"$JOB_ID\"}" \
    honeydew.Daemon/CancelJob
