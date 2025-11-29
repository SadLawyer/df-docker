#!/bin/bash

# MCP SSH Tunnel Setup Script
# This script creates SSH tunnels to access MCP containers without published ports

# Configuration
REMOTE_HOST="72.60.51.124"
REMOTE_USER="root"
SSH_KEY="/root/.ssh/mcp_rsa"

# Note: The SSH key is encrypted. You may be prompted for the passphrase.
# If you want to avoid the passphrase prompt, decrypt the key first:
# openssl rsa -in /root/.ssh/mcp_rsa -out /root/.ssh/mcp_rsa_decrypted
# Then update SSH_KEY above to point to the decrypted key

echo "Setting up SSH tunnels to MCP servers..."

# Tunnels for containers without published ports
# fetch-mcp: We need to find its internal IP first
# notion-mcp: We need to find its internal IP first

# First, let's discover the container IPs
echo "Discovering container IPs..."

# SSH into the remote host and get container information
ssh -i "$SSH_KEY" "$REMOTE_USER@$REMOTE_HOST" << 'EOF'
echo "Fetching container network information..."
docker ps --filter "label=com.docker.compose.project=mcp-servers" --format "{{.Names}}: {{.Networks}}"
echo ""
docker network inspect mcp-servers_default -f '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}'
EOF

echo ""
echo "Based on the output above, update this script with the correct IPs."
echo ""
echo "To create the tunnels, uncomment and modify the following lines:"
echo ""
echo "# For fetch-mcp (assuming IP 172.20.0.4:3000)"
echo "# ssh -i \"$SSH_KEY\" -f -N -L 3004:172.20.0.4:3000 \"$REMOTE_USER@$REMOTE_HOST\""
echo ""
echo "# For notion-mcp (assuming IP 172.20.0.5:3000)"
echo "# ssh -i \"$SSH_KEY\" -f -N -L 3005:172.20.0.5:3000 \"$REMOTE_USER@$REMOTE_HOST\""
echo ""
echo "These tunnels will map:"
echo "  - localhost:3004 -> fetch-mcp container"
echo "  - localhost:3005 -> notion-mcp container"
echo ""
echo "To kill all tunnels later, run: pkill -f 'ssh.*$REMOTE_HOST'"
