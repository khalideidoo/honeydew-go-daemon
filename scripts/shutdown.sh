#!/bin/bash
# Gracefully shutdown the daemon
set -e

SOCKET="${HONEYDEW_SOCKET:-$HOME/.honeydew/daemon.sock}"

if [[ ! -S "$SOCKET" ]]; then
    echo "Error: Daemon socket not found at $SOCKET"
    echo "Daemon may not be running."
    exit 1
fi

echo "Sending shutdown request..."
grpcurl -plaintext -unix "$SOCKET" honeydew.Daemon/Shutdown

echo "Daemon shutdown initiated."
