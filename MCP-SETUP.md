# MCP Server Configuration Guide

This guide explains how to configure and connect Claude Code to your MCP (Model Context Protocol) servers running in Docker containers.

## Important Network Considerations

**Note:** If you're running Claude Code in a containerized or restricted network environment (like Claude Code Web), you may not be able to directly access external IP addresses due to proxy restrictions. In such cases:

1. **Use this configuration on your local machine** where you have direct network access to the remote host
2. **Set up a reverse proxy** with a public URL that Claude Code can access
3. **Use Claude Code Desktop** instead of the web version, which may have fewer network restrictions

The configuration files in this repository are ready to use - just copy them to your local environment where you can access the remote host at 72.60.51.124.

## Overview

You have 4 MCP servers running in Docker containers on a remote host:

| Container | Image | Port Mapping | Internal IP | Access Method |
|-----------|-------|--------------|-------------|---------------|
| docker-mcp | mcp/docker:latest | 3002:3000 | 172.20.0.3 | Direct (published port) |
| filesystem-mcp | node:20-alpine | 3003:3000 | 172.20.0.2 | Direct (published port) |
| fetch-mcp | mcp/fetch:latest | None | TBD | SSH Tunnel required |
| notion-mcp | mcp/notion:latest | None | TBD | SSH Tunnel required |

**Remote Host:** 72.60.51.124
**Authentication:** Basic Auth (username: `claude`, password: `mcp2025`)

## Files Created

1. **`.mcp.json`** - MCP server configuration for Claude Code
2. **`setup-mcp-tunnels.sh`** - Script to create SSH tunnels for containers without published ports
3. **`stop-mcp-tunnels.sh`** - Script to stop all SSH tunnels
4. **`mcp-ssh-tunnel.sh`** - Helper script to discover container IPs
5. **`~/.ssh/mcp_rsa`** - SSH private key for remote access
6. **`~/.ssh/mcp_rsa.pub`** - SSH public key

## Quick Start

### 1. Set Up SSH Tunnels

For containers without published ports (fetch-mcp and notion-mcp), you need to create SSH tunnels:

```bash
cd /home/user/df-docker
./setup-mcp-tunnels.sh
```

**Note:** The SSH key is encrypted. You'll be prompted for the passphrase. If you don't know the passphrase or want to avoid entering it each time, you can:

1. **Decrypt the key** (if you have the passphrase):
   ```bash
   openssl rsa -in ~/.ssh/mcp_rsa -out ~/.ssh/mcp_rsa_decrypted
   chmod 600 ~/.ssh/mcp_rsa_decrypted
   ```
   Then update the scripts to use `~/.ssh/mcp_rsa_decrypted`

2. **Use password authentication instead:**
   Edit the scripts and replace `-i "$SSH_KEY"` with nothing, and use the password: `4fourEVERYyoung@`

### 2. Verify MCP Configuration

The MCP configuration file `.mcp.json` has been created with all four servers:

```json
{
  "mcpServers": {
    "docker-mcp": {
      "type": "http",
      "url": "http://72.60.51.124:3002",
      "headers": {
        "Authorization": "Basic Y2xhdWRlOm1jcDIwMjU=",
        "Content-Type": "application/json"
      }
    },
    "filesystem-mcp": {
      "type": "http",
      "url": "http://72.60.51.124:3003",
      "headers": {
        "Authorization": "Basic Y2xhdWRlOm1jcDIwMjU=",
        "Content-Type": "application/json"
      }
    },
    "fetch-mcp": {
      "type": "http",
      "url": "http://localhost:3004",
      "headers": {
        "Authorization": "Basic Y2xhdWRlOm1jcDIwMjU=",
        "Content-Type": "application/json"
      }
    },
    "notion-mcp": {
      "type": "http",
      "url": "http://localhost:3005",
      "headers": {
        "Authorization": "Basic Y2xhdWRlOm1jcDIwMjU=",
        "Content-Type": "application/json"
      }
    }
  }
}
```

### 3. Test Connections

Once tunnels are set up, test the connections:

```bash
# Test docker-mcp (direct connection)
curl -H "Authorization: Basic Y2xhdWRlOm1jcDIwMjU=" http://72.60.51.124:3002/health

# Test filesystem-mcp (direct connection)
curl -H "Authorization: Basic Y2xhdWRlOm1jcDIwMjU=" http://72.60.51.124:3003/health

# Test fetch-mcp (via tunnel)
curl -H "Authorization: Basic Y2xhdWRlOm1jcDIwMjU=" http://localhost:3004/health

# Test notion-mcp (via tunnel)
curl -H "Authorization: Basic Y2xhdWRlOm1jcDIwMjU=" http://localhost:3005/health
```

### 4. Use in Claude Code

Once configured, you can use MCP servers in Claude Code. The servers will automatically be available in your session.

To verify MCP servers are loaded, you can check with:
```bash
# If claude CLI is available
claude mcp list
```

Or within Claude Code, check the MCP status using the `/mcp` command (if available).

## Managing SSH Tunnels

### Start Tunnels
```bash
./setup-mcp-tunnels.sh
```

### Check Tunnel Status
```bash
ps aux | grep 'ssh.*72.60.51.124'
```

### Stop Tunnels
```bash
./stop-mcp-tunnels.sh
```

## Troubleshooting

### SSH Key Passphrase Issues

If you're repeatedly prompted for the SSH key passphrase, you have several options:

1. **Use SSH Agent:**
   ```bash
   eval $(ssh-agent)
   ssh-add ~/.ssh/mcp_rsa
   # Enter passphrase once
   ```

2. **Decrypt the key permanently:**
   ```bash
   openssl rsa -in ~/.ssh/mcp_rsa -out ~/.ssh/mcp_rsa_decrypted
   chmod 600 ~/.ssh/mcp_rsa_decrypted
   # Update scripts to use the decrypted key
   ```

3. **Use password authentication:**
   Remove the `-i "$SSH_KEY"` option from scripts and use the password when prompted: `4fourEVERYyoung@`

### Container IP Discovery

If you need to find the container IPs manually:

```bash
ssh root@72.60.51.124
# Enter password: 4fourEVERYyoung@

# Once connected:
docker ps --filter "label=com.docker.compose.project=mcp-servers"
docker inspect <container-id> | grep IPAddress
```

### Port Already in Use

If you get "port already in use" errors:

```bash
# Find what's using the port
lsof -i :3004
lsof -i :3005

# Kill the process or change the port mapping in .mcp.json
```

### Connection Refused

If you get connection refused errors:

1. **Check if containers are running:**
   ```bash
   ssh root@72.60.51.124 "docker ps"
   ```

2. **Check container logs:**
   ```bash
   ssh root@72.60.51.124 "docker logs <container-name>"
   ```

3. **Verify firewall rules:**
   Make sure ports 3002 and 3003 are open on the remote host

### MCP Server Not Responding

1. **Check if the MCP server requires additional configuration** (API keys, tokens, etc.)

2. **Verify the authentication** is correct:
   ```bash
   echo -n 'claude:mcp2025' | base64
   # Should output: Y2xhdWRlOm1jcDIwMjU=
   ```

3. **Check the response** from the server:
   ```bash
   curl -v -H "Authorization: Basic Y2xhdWRlOm1jcDIwMjU=" http://72.60.51.124:3002/
   ```

## Security Notes

1. **SSH Keys**: The private SSH key is stored at `~/.ssh/mcp_rsa` and is encrypted. Keep this secure.

2. **Credentials**: Basic auth credentials are embedded in `.mcp.json`. Do not commit this file to public repositories.

3. **Network Security**: The tunnels create local ports that forward to remote containers. Ensure your local machine is secure.

4. **Gitignore**: Consider adding to `.gitignore`:
   ```
   .mcp.json
   *.sh
   ```

## Environment Variables (Alternative Configuration)

If you prefer to use environment variables instead of hardcoded credentials:

1. Update `.mcp.json` to use environment variables:
   ```json
   {
     "mcpServers": {
       "docker-mcp": {
         "type": "http",
         "url": "http://72.60.51.124:3002",
         "headers": {
           "Authorization": "Basic ${MCP_AUTH_TOKEN}"
         }
       }
     }
   }
   ```

2. Export the variable:
   ```bash
   export MCP_AUTH_TOKEN="Y2xhdWRlOm1jcDIwMjU="
   ```

## Additional Resources

- Remote Host: `ssh root@72.60.51.124` (password: `4fourEVERYyoung@`)
- Portainer UI: Check the screenshots for the Portainer interface URL
- Docker Network: `mcp-servers_default`

## Next Steps

1. Run `./setup-mcp-tunnels.sh` to establish connections
2. Test each MCP server endpoint
3. Start using the MCP servers in your Claude Code sessions
4. Set up automatic tunnel startup (optional - add to shell profile)

---

For more information about MCP servers, visit the Model Context Protocol documentation.
