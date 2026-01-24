#!/bin/bash
# List all scheduled jobs
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Is the daemon running?"
    exit 1
fi

grpcurl -plaintext -unix "$SOCKET" honeydew.Daemon/ListSchedules
