#!/bin/bash

# Stop MCP SSH Tunnels Script

REMOTE_HOST="72.60.51.124"

echo "Stopping MCP SSH tunnels..."

# Find and kill SSH tunnel processes
TUNNEL_PIDS=$(pgrep -f "ssh.*${REMOTE_HOST}")

if [ -z "$TUNNEL_PIDS" ]; then
    echo "No active tunnels found."
else
    echo "Found tunnel processes: $TUNNEL_PIDS"
    pkill -f "ssh.*${REMOTE_HOST}"
    echo "All tunnels stopped."
fi

# Verify
sleep 1
REMAINING=$(pgrep -f "ssh.*${REMOTE_HOST}")
if [ -z "$REMAINING" ]; then
    echo "✓ All tunnels successfully closed."
else
    echo "Warning: Some processes may still be running: $REMAINING"
fi
