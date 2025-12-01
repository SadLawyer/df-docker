#!/bin/bash
# Script para interagir com o MCP Server no container Docker

CONTAINER_NAME="df-mcp-server"

# Verificar se o container está rodando
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Erro: Container $CONTAINER_NAME não está rodando."
    echo "Execute 'docker-compose up -d mcp-server' primeiro."
    exit 1
fi

# Função para executar comandos no MCP server
case "$1" in
    exec)
        shift
        docker exec -it "$CONTAINER_NAME" "$@"
        ;;
    logs)
        docker logs -f "$CONTAINER_NAME"
        ;;
    shell)
        docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;
    restart)
        docker-compose restart mcp-server
        ;;
    status)
        docker ps | grep "$CONTAINER_NAME" || echo "Container não está rodando"
        ;;
    *)
        echo "Uso: $0 {exec|logs|shell|restart|status}"
        echo ""
        echo "Comandos:"
        echo "  exec <cmd>  - Executar comando no container"
        echo "  logs        - Ver logs do container"
        echo "  shell       - Abrir shell no container"
        echo "  restart     - Reiniciar o container"
        echo "  status      - Ver status do container"
        exit 1
        ;;
esac
