#!/bin/bash

# Complete MCP Tunnel Setup Script
# Creates SSH tunnels for all MCP containers

set -e

REMOTE_HOST="72.60.51.124"
REMOTE_USER="root"
SSH_KEY="/root/.ssh/mcp_rsa"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "=== MCP Server SSH Tunnel Setup ==="
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found at $SSH_KEY"
    exit 1
fi

# Check if key is encrypted
if grep -q "ENCRYPTED" "$SSH_KEY"; then
    echo "Note: The SSH key is encrypted. You will be prompted for the passphrase."
    echo "To avoid this, decrypt the key with:"
    echo "  openssl rsa -in $SSH_KEY -out ${SSH_KEY}_decrypted"
    echo ""
fi

# Function to check if tunnel is already running
check_tunnel() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo "Warning: Port $port is already in use"
        return 1
    fi
    return 0
}

# Function to create SSH tunnel
create_tunnel() {
    local local_port=$1
    local remote_ip=$2
    local remote_port=$3
    local name=$4

    echo "Creating tunnel for $name: localhost:$local_port -> $remote_ip:$remote_port"

    if check_tunnel $local_port; then
        ssh -i "$SSH_KEY" $SSH_OPTS -f -N -L ${local_port}:${remote_ip}:${remote_port} "${REMOTE_USER}@${REMOTE_HOST}"
        if [ $? -eq 0 ]; then
            echo "  ✓ Tunnel created successfully"
        else
            echo "  ✗ Failed to create tunnel"
            return 1
        fi
    else
        echo "  ✗ Skipping (port in use)"
        return 1
    fi
}

echo "Step 1: Getting container network information from remote host..."
echo ""

# Get container IPs
CONTAINER_INFO=$(ssh -i "$SSH_KEY" $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
    "docker inspect -f '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    \$(docker ps -q --filter 'label=com.docker.compose.project=mcp-servers')" 2>/dev/null)

echo "Container Information:"
echo "$CONTAINER_INFO"
echo ""

# Parse IPs (you may need to adjust these based on actual container names)
DOCKER_MCP_IP=$(echo "$CONTAINER_INFO" | grep "docker-mcp" | awk '{print $2}' | head -1)
FETCH_MCP_IP=$(echo "$CONTAINER_INFO" | grep "fetch-mcp" | awk '{print $2}' | head -1)
FILESYSTEM_MCP_IP=$(echo "$CONTAINER_INFO" | grep "filesystem-mcp" | awk '{print $2}' | head -1)
NOTION_MCP_IP=$(echo "$CONTAINER_INFO" | grep "notion-mcp" | awk '{print $2}' | head -1)

echo "Detected IPs:"
echo "  docker-mcp:     ${DOCKER_MCP_IP:-Not found}"
echo "  fetch-mcp:      ${FETCH_MCP_IP:-Not found}"
echo "  filesystem-mcp: ${FILESYSTEM_MCP_IP:-Not found}"
echo "  notion-mcp:     ${NOTION_MCP_IP:-Not found}"
echo ""

echo "Step 2: Creating SSH tunnels..."
echo ""

# Create tunnels for containers without published ports
if [ -n "$FETCH_MCP_IP" ]; then
    create_tunnel 3004 "$FETCH_MCP_IP" 3000 "fetch-mcp"
else
    echo "Warning: Could not find IP for fetch-mcp, skipping tunnel"
fi

if [ -n "$NOTION_MCP_IP" ]; then
    create_tunnel 3005 "$NOTION_MCP_IP" 3000 "notion-mcp"
else
    echo "Warning: Could not find IP for notion-mcp, skipping tunnel"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "MCP servers are now accessible at:"
echo "  docker-mcp:     http://72.60.51.124:3002 (direct)"
echo "  filesystem-mcp: http://72.60.51.124:3003 (direct)"
if [ -n "$FETCH_MCP_IP" ]; then
    echo "  fetch-mcp:      http://localhost:3004 (via tunnel)"
fi
if [ -n "$NOTION_MCP_IP" ]; then
    echo "  notion-mcp:     http://localhost:3005 (via tunnel)"
fi
echo ""
echo "To verify tunnels are running:"
echo "  ps aux | grep 'ssh.*${REMOTE_HOST}'"
echo ""
echo "To close all tunnels:"
echo "  pkill -f 'ssh.*${REMOTE_HOST}'"
echo ""
