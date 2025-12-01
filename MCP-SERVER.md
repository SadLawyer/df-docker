# MCP Server Commands - Configuração Docker

Este projeto inclui o [MCP Server Commands](https://github.com/g0t4/mcp-server-commands) como um serviço Docker separado que permite que LLMs como Claude executem comandos shell em um ambiente containerizado.

## O que é MCP Server?

O Model Context Protocol (MCP) Server permite que assistentes de IA executem comandos shell de forma segura. O servidor expõe uma ferramenta `run_command` que pode executar comandos e retornar a saída.

## Arquitetura

O MCP Server roda em um container Docker separado (`df-mcp-server`) que:
- Usa Node.js 20 Alpine como base
- Inclui bash, curl, git, python3 e ferramentas de build
- Tem acesso a um volume persistente em `/data`
- Pode se comunicar com outros containers na rede Docker

## Iniciando o Serviço

### 1. Build e Start
```bash
docker-compose build mcp-server
docker-compose up -d mcp-server
```

### 2. Verificar Status
```bash
./mcp-cli.sh status
# ou
docker ps | grep df-mcp-server
```

### 3. Ver Logs
```bash
./mcp-cli.sh logs
# ou
docker logs -f df-mcp-server
```

## Usando o MCP Server

### Com Claude Desktop

1. Localize seu arquivo de configuração do Claude Desktop:
   - **MacOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows**: `%APPDATA%/Claude/claude_desktop_config.json`

2. Adicione a configuração do MCP Server:
```json
{
  "mcpServers": {
    "docker-commands": {
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "df-mcp-server",
        "npx",
        "mcp-server-commands"
      ]
    }
  }
}
```

3. Reinicie o Claude Desktop

### Com Claude Code ou Outros Clientes

Use o arquivo de configuração de exemplo `mcp-config.example.json` como referência.

## Script de Gerenciamento

O script `mcp-cli.sh` fornece comandos úteis:

```bash
# Executar comando no container
./mcp-cli.sh exec ls -la /data

# Abrir shell interativo
./mcp-cli.sh shell

# Ver logs em tempo real
./mcp-cli.sh logs

# Reiniciar o serviço
./mcp-cli.sh restart

# Verificar status
./mcp-cli.sh status
```

## Comandos Úteis

### Executar Comando Diretamente
```bash
docker exec df-mcp-server sh -c "ls -la /data"
```

### Acessar Shell Interativo
```bash
docker exec -it df-mcp-server /bin/bash
```

### Copiar Arquivos para o Container
```bash
docker cp arquivo.txt df-mcp-server:/data/
```

### Copiar Arquivos do Container
```bash
docker cp df-mcp-server:/data/arquivo.txt ./
```

## Volumes

- **mcp-data**: Volume persistente montado em `/data` no container para armazenar dados

## Segurança

⚠️ **IMPORTANTE**:
- Sempre revise os comandos antes de executá-los
- Não execute o MCP Server com privilégios elevados (sudo)
- Aprove comandos individualmente ao usar com Claude
- O container tem acesso limitado apenas aos recursos Docker padrão

### Acesso ao Docker (Opcional)

Se precisar executar comandos Docker dentro do MCP Server, descomente a linha no `docker-compose.yml`:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

⚠️ **Atenção**: Isso dá acesso total ao Docker host e deve ser usado com cuidado.

## Rede

O MCP Server pode se comunicar com outros serviços Docker:
- **web**: Container DreamFactory (http://web)
- **mysql**: Banco de dados MySQL (mysql:3306)
- **redis**: Cache Redis (redis:6379)
- **example_data**: Banco de dados Postgres de exemplo

Exemplo de uso:
```bash
# Conectar ao MySQL
docker exec df-mcp-server sh -c "apk add mysql-client && mysql -h mysql -u df_admin -pdf_admin dreamfactory"
```

## Troubleshooting

### Container não inicia
```bash
docker-compose logs mcp-server
docker-compose up mcp-server  # Ver logs em tempo real
```

### Reinstalar dependências
```bash
docker-compose down mcp-server
docker-compose build --no-cache mcp-server
docker-compose up -d mcp-server
```

### Limpar dados persistentes
```bash
docker-compose down -v  # Remove TODOS os volumes (cuidado!)
# ou apenas o volume MCP:
docker volume rm df-docker_mcp-data
```

## Customização

### Adicionar Ferramentas

Edite `Dockerfile.mcp` para adicionar mais ferramentas:

```dockerfile
RUN apk add --no-cache \
    postgresql-client \
    vim \
    htop \
    # suas ferramentas aqui
```

Depois rebuild:
```bash
docker-compose build mcp-server
docker-compose up -d mcp-server
```

## Referências

- [MCP Server Commands](https://github.com/g0t4/mcp-server-commands)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Documentação Claude Desktop](https://docs.anthropic.com/claude/docs)
