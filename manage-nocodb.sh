#!/bin/bash

# NocoDB Management Script
# Manage NocoDB containers on remote server

set -e

# Configuration
REMOTE_HOST="72.60.51.124"
REMOTE_USER="root"
REMOTE_PASSWORD="4fourEVERYyoung@"
REMOTE_DIR="/opt/nocodb"
SSH_PORT="22"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to execute remote commands
execute_remote() {
    sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "$1"
}

# Detect Docker Compose command
detect_compose_cmd() {
    if execute_remote "docker compose version >/dev/null 2>&1"; then
        echo "docker compose"
    elif execute_remote "docker-compose --version >/dev/null 2>&1"; then
        echo "docker-compose"
    else
        echo ""
    fi
}

COMPOSE_CMD=$(detect_compose_cmd)

if [ -z "$COMPOSE_CMD" ]; then
    echo -e "${RED}Error: Docker Compose not found on remote server${NC}"
    exit 1
fi

# Show usage
show_usage() {
    echo -e "${GREEN}NocoDB Management Script${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo -e "  ${YELLOW}start${NC}      - Start NocoDB containers"
    echo -e "  ${YELLOW}stop${NC}       - Stop NocoDB containers"
    echo -e "  ${YELLOW}restart${NC}    - Restart NocoDB containers"
    echo -e "  ${YELLOW}status${NC}     - Show container status"
    echo -e "  ${YELLOW}logs${NC}       - Show container logs (follow mode)"
    echo -e "  ${YELLOW}logs-tail${NC}  - Show last 50 lines of logs"
    echo -e "  ${YELLOW}ps${NC}         - List all containers"
    echo -e "  ${YELLOW}health${NC}     - Check health status"
    echo -e "  ${YELLOW}backup${NC}     - Backup PostgreSQL database"
    echo -e "  ${YELLOW}restore${NC}    - Restore PostgreSQL database"
    echo -e "  ${YELLOW}update${NC}     - Update to latest version"
    echo -e "  ${YELLOW}down${NC}       - Stop and remove containers"
    echo -e "  ${YELLOW}clean${NC}      - Remove containers and volumes (⚠️  DATA LOSS)"
    echo ""
}

# Command handlers
cmd_start() {
    echo -e "${YELLOW}Starting NocoDB...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD start"
    echo -e "${GREEN}✓ NocoDB started${NC}"
}

cmd_stop() {
    echo -e "${YELLOW}Stopping NocoDB...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD stop"
    echo -e "${GREEN}✓ NocoDB stopped${NC}"
}

cmd_restart() {
    echo -e "${YELLOW}Restarting NocoDB...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD restart"
    echo -e "${GREEN}✓ NocoDB restarted${NC}"
}

cmd_status() {
    echo -e "${YELLOW}Container Status:${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD ps"
}

cmd_logs() {
    echo -e "${YELLOW}Following logs (Ctrl+C to exit)...${NC}"
    sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SSH_PORT" -t "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && $COMPOSE_CMD logs -f"
}

cmd_logs_tail() {
    echo -e "${YELLOW}Last 50 lines of logs:${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD logs --tail=50"
}

cmd_ps() {
    echo -e "${YELLOW}All containers:${NC}"
    execute_remote "docker ps -a --filter 'name=nocodb'"
}

cmd_health() {
    echo -e "${YELLOW}Health Check:${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD ps"
    echo ""
    echo -e "${YELLOW}Testing NocoDB API...${NC}"
    if execute_remote "curl -f http://localhost:8080/api/v1/health 2>/dev/null"; then
        echo -e "${GREEN}✓ NocoDB is healthy${NC}"
    else
        echo -e "${RED}✗ NocoDB is not responding${NC}"
    fi
}

cmd_backup() {
    BACKUP_FILE="nocodb_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD exec -T nocodb-postgres pg_dump -U nocodb nocodb > $BACKUP_FILE"
    echo -e "${GREEN}✓ Backup created: $REMOTE_DIR/$BACKUP_FILE${NC}"
    echo -e "${BLUE}To download: scp root@$REMOTE_HOST:$REMOTE_DIR/$BACKUP_FILE .${NC}"
}

cmd_restore() {
    if [ -z "$2" ]; then
        echo -e "${RED}Error: Please provide backup file path${NC}"
        echo "Usage: $0 restore <backup-file>"
        exit 1
    fi
    BACKUP_FILE="$2"
    echo -e "${YELLOW}Restoring from: $BACKUP_FILE${NC}"
    echo -e "${RED}⚠️  This will overwrite the current database. Continue? (y/n)${NC}"
    read -r confirm
    if [ "$confirm" = "y" ]; then
        execute_remote "cd $REMOTE_DIR && cat $BACKUP_FILE | $COMPOSE_CMD exec -T nocodb-postgres psql -U nocodb -d nocodb"
        echo -e "${GREEN}✓ Database restored${NC}"
    else
        echo -e "${YELLOW}Restore cancelled${NC}"
    fi
}

cmd_update() {
    echo -e "${YELLOW}Updating NocoDB to latest version...${NC}"
    echo -e "${BLUE}Creating backup first...${NC}"
    cmd_backup
    echo -e "${YELLOW}Pulling latest images...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD pull"
    echo -e "${YELLOW}Restarting with new images...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD up -d"
    echo -e "${GREEN}✓ Update complete${NC}"
}

cmd_down() {
    echo -e "${YELLOW}Stopping and removing containers...${NC}"
    execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD down"
    echo -e "${GREEN}✓ Containers removed (volumes preserved)${NC}"
}

cmd_clean() {
    echo -e "${RED}⚠️  WARNING: This will remove all containers and volumes!${NC}"
    echo -e "${RED}⚠️  All data will be permanently deleted!${NC}"
    echo -e "${YELLOW}Are you sure? Type 'yes' to confirm:${NC}"
    read -r confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Removing everything...${NC}"
        execute_remote "cd $REMOTE_DIR && $COMPOSE_CMD down -v"
        echo -e "${GREEN}✓ All containers and volumes removed${NC}"
    else
        echo -e "${YELLOW}Clean cancelled${NC}"
    fi
}

# Main
if [ -z "$1" ]; then
    show_usage
    exit 0
fi

case "$1" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    logs-tail)
        cmd_logs_tail
        ;;
    ps)
        cmd_ps
        ;;
    health)
        cmd_health
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore "$@"
        ;;
    update)
        cmd_update
        ;;
    down)
        cmd_down
        ;;
    clean)
        cmd_clean
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
