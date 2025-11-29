#!/bin/bash

# NocoDB Deployment Script
# This script deploys NocoDB with PostgreSQL to the remote server

set -e

# Configuration
REMOTE_HOST="72.60.51.124"
REMOTE_USER="root"
REMOTE_PASSWORD="4fourEVERYyoung@"
REMOTE_DIR="/opt/nocodb"
SSH_PORT="22"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}NocoDB Deployment Script${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Function to execute remote commands
execute_remote() {
    sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "$1"
}

# Function to copy files to remote
copy_to_remote() {
    sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no -P "$SSH_PORT" "$1" "$REMOTE_USER@$REMOTE_HOST:$2"
}

# Test connection
echo -e "${YELLOW}Testing connection to $REMOTE_HOST...${NC}"
if execute_remote "echo 'Connection successful'"; then
    echo -e "${GREEN}✓ Connection established${NC}"
else
    echo -e "${RED}✗ Failed to connect to remote server${NC}"
    echo -e "${YELLOW}Trying alternative SSH ports...${NC}"

    # Try common alternative SSH ports
    for port in 2222 2200 22222; do
        echo -e "${YELLOW}Trying port $port...${NC}"
        SSH_PORT=$port
        if execute_remote "echo 'Connection successful'" 2>/dev/null; then
            echo -e "${GREEN}✓ Connection established on port $port${NC}"
            break
        fi
    done

    if ! execute_remote "echo 'Connection successful'" 2>/dev/null; then
        echo -e "${RED}✗ Could not connect on any port. Please check:${NC}"
        echo "  1. Server is accessible"
        echo "  2. SSH port is correct"
        echo "  3. Firewall settings"
        exit 1
    fi
fi

# Create remote directory
echo -e "${YELLOW}Creating remote directory...${NC}"
execute_remote "mkdir -p $REMOTE_DIR"
echo -e "${GREEN}✓ Directory created: $REMOTE_DIR${NC}"

# Copy docker-compose file
echo -e "${YELLOW}Copying docker-compose configuration...${NC}"
copy_to_remote "docker-compose.nocodb.yml" "$REMOTE_DIR/docker-compose.yml"
echo -e "${GREEN}✓ Docker Compose file copied${NC}"

# Copy environment file if it exists
if [ -f ".env.nocodb" ]; then
    echo -e "${YELLOW}Copying environment file...${NC}"
    copy_to_remote ".env.nocodb" "$REMOTE_DIR/.env"
    echo -e "${GREEN}✓ Environment file copied${NC}"
else
    echo -e "${YELLOW}No .env.nocodb file found, using defaults from docker-compose.yml${NC}"
fi

# Check if Docker is installed on remote
echo -e "${YELLOW}Checking Docker installation...${NC}"
if execute_remote "command -v docker >/dev/null 2>&1"; then
    echo -e "${GREEN}✓ Docker is installed${NC}"
else
    echo -e "${RED}✗ Docker is not installed on the remote server${NC}"
    echo -e "${YELLOW}Would you like to install Docker? (y/n)${NC}"
    read -r install_docker
    if [ "$install_docker" = "y" ]; then
        echo -e "${YELLOW}Installing Docker...${NC}"
        execute_remote "curl -fsSL https://get.docker.com | sh"
        echo -e "${GREEN}✓ Docker installed${NC}"
    else
        echo -e "${RED}Cannot proceed without Docker. Exiting.${NC}"
        exit 1
    fi
fi

# Check if Docker Compose is available
echo -e "${YELLOW}Checking Docker Compose...${NC}"
if execute_remote "docker compose version >/dev/null 2>&1"; then
    echo -e "${GREEN}✓ Docker Compose (v2) is available${NC}"
    COMPOSE_CMD="docker compose"
elif execute_remote "docker-compose --version >/dev/null 2>&1"; then
    echo -e "${GREEN}✓ Docker Compose (v1) is available${NC}"
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    exit 1
fi

# Stop existing containers (if any)
echo -e "${YELLOW}Stopping existing NocoDB containers...${NC}"
execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD down" || echo "No existing containers to stop"

# Pull latest images
echo -e "${YELLOW}Pulling latest Docker images...${NC}"
execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD pull"
echo -e "${GREEN}✓ Images pulled${NC}"

# Start containers
echo -e "${YELLOW}Starting NocoDB containers...${NC}"
execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD up -d"
echo -e "${GREEN}✓ Containers started${NC}"

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
sleep 10

# Check container status
echo -e "${YELLOW}Checking container status...${NC}"
execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD ps"

# Get container logs
echo -e "${YELLOW}Recent container logs:${NC}"
execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD logs --tail=20"

# Final instructions
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${GREEN}NocoDB is now running on:${NC}"
echo -e "  ${YELLOW}http://$REMOTE_HOST:8080${NC}"
echo ""
echo -e "${GREEN}Default credentials:${NC}"
echo -e "  Email: ${YELLOW}admin@nocodb.com${NC}"
echo -e "  Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANT: Change the default password after first login!${NC}"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  View logs:    ssh root@$REMOTE_HOST 'cd $REMOTE_DIR && $COMPOSE_CMD logs -f'"
echo "  Stop:         ssh root@$REMOTE_HOST 'cd $REMOTE_DIR && $COMPOSE_CMD stop'"
echo "  Start:        ssh root@$REMOTE_HOST 'cd $REMOTE_DIR && $COMPOSE_CMD start'"
echo "  Restart:      ssh root@$REMOTE_HOST 'cd $REMOTE_DIR && $COMPOSE_CMD restart'"
echo "  Status:       ssh root@$REMOTE_HOST 'cd $REMOTE_DIR && $COMPOSE_CMD ps'"
echo ""
