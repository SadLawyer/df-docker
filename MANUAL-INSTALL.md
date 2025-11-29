# Guia de Instalação Manual do NocoDB

Este guia fornece instruções passo a passo para instalar o NocoDB diretamente no servidor.

## 🚀 Instalação Rápida

### Passo 1: Conectar ao Servidor

```bash
ssh root@72.60.51.124
# Senha: 4fourEVERYyoung@
```

### Passo 2: Criar Diretório do Projeto

```bash
mkdir -p /opt/nocodb
cd /opt/nocodb
```

### Passo 3: Criar o arquivo docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database for NocoDB
  nocodb-postgres:
    image: postgres:15-alpine
    container_name: nocodb-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: nocodb
      POSTGRES_USER: nocodb
      POSTGRES_PASSWORD: nocodb_secure_password_2024
    volumes:
      - nocodb-postgres-data:/var/lib/postgresql/data
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nocodb -d nocodb"]
      interval: 10s
      timeout: 5s
      retries: 5

  # NocoDB Application
  nocodb:
    image: nocodb/nocodb:latest
    container_name: nocodb
    restart: unless-stopped
    depends_on:
      nocodb-postgres:
        condition: service_healthy
    environment:
      # Database Configuration
      NC_DB: "pg://nocodb-postgres:5432?u=nocodb&p=nocodb_secure_password_2024&d=nocodb"

      # Application Settings
      NC_AUTH_JWT_SECRET: "your-super-secret-jwt-key-change-this-in-production"
      NC_PUBLIC_URL: "http://72.60.51.124:8080"

      # Storage Configuration
      NC_ATTACHMENT_FIELD_SIZE: "20971520"
      NC_MAX_ATTACHMENTS_ALLOWED: "10"

      # Disable telemetry
      NC_DISABLE_TELE: "true"

      # Admin credentials
      NC_ADMIN_EMAIL: "admin@nocodb.com"
      NC_ADMIN_PASSWORD: "admin123"
    volumes:
      - nocodb-data:/usr/app/data
    ports:
      - "8080:8080"
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/api/v1/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  nocodb-network:
    driver: bridge

volumes:
  nocodb-postgres-data:
    driver: local
  nocodb-data:
    driver: local
EOF
```

### Passo 4: Verificar se Docker está Instalado

```bash
docker --version
```

Se o Docker não estiver instalado, instale-o:

```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Habilitar e iniciar Docker
systemctl enable docker
systemctl start docker
```

### Passo 5: Iniciar o NocoDB

```bash
# Baixar as imagens
docker compose pull

# Iniciar os containers
docker compose up -d

# Verificar o status
docker compose ps
```

### Passo 6: Verificar os Logs

```bash
# Ver logs de todos os containers
docker compose logs -f

# Ver apenas logs do NocoDB
docker compose logs -f nocodb

# Ver apenas logs do PostgreSQL
docker compose logs -f nocodb-postgres
```

### Passo 7: Testar o Acesso

```bash
# Testar API de saúde
curl http://localhost:8080/api/v1/health

# Verificar status dos containers
docker compose ps
```

### Passo 8: Configurar Firewall (se necessário)

```bash
# Verificar status do firewall
ufw status

# Se o firewall estiver ativo, liberar a porta 8080
ufw allow 8080/tcp
ufw reload
```

## 🌐 Acessar o NocoDB

Após a instalação, acesse:

**URL**: http://72.60.51.124:8080

**Credenciais Padrão**:
- Email: `admin@nocodb.com`
- Password: `admin123`

⚠️ **IMPORTANTE**: Mude a senha padrão imediatamente após o primeiro login!

## 🛠️ Comandos Úteis

### Gerenciamento de Containers

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f

# Parar containers
docker compose stop

# Iniciar containers
docker compose start

# Reiniciar containers
docker compose restart

# Parar e remover containers (mantém dados)
docker compose down

# Parar e remover containers E dados (⚠️ CUIDADO)
docker compose down -v
```

### Backup do Banco de Dados

```bash
# Criar backup
docker compose exec nocodb-postgres pg_dump -U nocodb nocodb > backup_$(date +%Y%m%d_%H%M%S).sql

# Listar backups
ls -lh backup_*.sql
```

### Restaurar Backup

```bash
# Parar o NocoDB
docker compose stop nocodb

# Restaurar backup
cat backup_YYYYMMDD_HHMMSS.sql | docker compose exec -T nocodb-postgres psql -U nocodb -d nocodb

# Reiniciar o NocoDB
docker compose start nocodb
```

### Atualizar para Última Versão

```bash
# Criar backup primeiro!
docker compose exec nocodb-postgres pg_dump -U nocodb nocodb > backup_before_update_$(date +%Y%m%d).sql

# Baixar novas imagens
docker compose pull

# Reiniciar com novas imagens
docker compose up -d
```

### Ver Uso de Recursos

```bash
# Ver uso de CPU/Memória
docker stats nocodb nocodb-postgres

# Ver espaço em disco dos volumes
docker system df -v
```

## 🔧 Customização

### Mudar a Porta

Edite o `docker-compose.yml` e mude a linha:

```yaml
ports:
  - "8081:8080"  # Mude 8081 para a porta desejada
```

Depois reinicie:

```bash
docker compose down
docker compose up -d
```

### Configurar SMTP para Emails

Edite o `docker-compose.yml` e adicione as variáveis de ambiente:

```yaml
environment:
  # ... outras variáveis ...
  NC_SMTP_FROM: "noreply@seudominio.com"
  NC_SMTP_HOST: "smtp.gmail.com"
  NC_SMTP_PORT: "587"
  NC_SMTP_USERNAME: "seu-email@gmail.com"
  NC_SMTP_PASSWORD: "sua-senha-de-app"
  NC_SMTP_SECURE: "true"
```

Depois reinicie:

```bash
docker compose restart nocodb
```

### Habilitar Redis (para melhor performance)

Edite o `docker-compose.yml` e descomente a seção do Redis:

```yaml
  nocodb-redis:
    image: redis:7-alpine
    container_name: nocodb-redis
    restart: unless-stopped
    volumes:
      - nocodb-redis-data:/data
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

E adicione nas variáveis de ambiente do NocoDB:

```yaml
NC_REDIS_URL: "redis://nocodb-redis:6379"
```

Não esqueça de descomentar o volume:

```yaml
volumes:
  nocodb-postgres-data:
    driver: local
  nocodb-data:
    driver: local
  nocodb-redis-data:
    driver: local
```

Depois reinicie:

```bash
docker compose down
docker compose up -d
```

## 🔒 Segurança

### 1. Mudar Senhas Padrão

Edite o `docker-compose.yml` e mude:

- `POSTGRES_PASSWORD`
- `NC_AUTH_JWT_SECRET` (gere uma chave aleatória longa)
- `NC_ADMIN_PASSWORD`

```bash
# Gerar chave aleatória para JWT
openssl rand -base64 32
```

### 2. Configurar HTTPS com Nginx

```bash
# Instalar Nginx
apt update
apt install nginx certbot python3-certbot-nginx -y

# Criar configuração
cat > /etc/nginx/sites-available/nocodb << 'EOF'
server {
    listen 80;
    server_name nocodb.seudominio.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Habilitar site
ln -s /etc/nginx/sites-available/nocodb /etc/nginx/sites-enabled/

# Testar configuração
nginx -t

# Reiniciar Nginx
systemctl restart nginx

# Obter certificado SSL
certbot --nginx -d nocodb.seudominio.com
```

### 3. Configurar Firewall

```bash
# Habilitar UFW
ufw enable

# Permitir SSH
ufw allow 22/tcp

# Permitir HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Se NÃO usar Nginx, permitir porta 8080
ufw allow 8080/tcp

# Verificar status
ufw status
```

### 4. Backups Automáticos

```bash
# Criar script de backup
cat > /opt/nocodb/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/nocodb/backups"
mkdir -p $BACKUP_DIR
cd /opt/nocodb
docker compose exec -T nocodb-postgres pg_dump -U nocodb nocodb > $BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql
# Manter apenas últimos 7 dias
find $BACKUP_DIR -name "backup_*.sql" -mtime +7 -delete
EOF

# Tornar executável
chmod +x /opt/nocodb/backup.sh

# Adicionar ao cron (backup diário às 2h da manhã)
crontab -e
# Adicione esta linha:
# 0 2 * * * /opt/nocodb/backup.sh
```

## 🐛 Solução de Problemas

### Container não inicia

```bash
# Ver logs detalhados
docker compose logs nocodb
docker compose logs nocodb-postgres

# Verificar configuração
docker compose config

# Reiniciar do zero
docker compose down
docker compose up -d
```

### Não consigo acessar a interface

```bash
# Verificar se o container está rodando
docker compose ps

# Verificar portas
netstat -tulpn | grep 8080

# Verificar firewall
ufw status

# Testar localmente
curl http://localhost:8080/api/v1/health
```

### Erro de banco de dados

```bash
# Verificar logs do PostgreSQL
docker compose logs nocodb-postgres

# Verificar se PostgreSQL está saudável
docker compose exec nocodb-postgres pg_isready -U nocodb

# Conectar ao PostgreSQL
docker compose exec nocodb-postgres psql -U nocodb -d nocodb
```

### Performance lenta

1. Habilite Redis (veja seção de customização)
2. Aumente recursos do container
3. Otimize PostgreSQL

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

## 📊 Monitoramento

### Verificar saúde do sistema

```bash
# Status dos containers
docker compose ps

# Uso de recursos
docker stats

# Espaço em disco
df -h
docker system df

# Logs em tempo real
docker compose logs -f
```

### Health Checks

```bash
# NocoDB API
curl http://localhost:8080/api/v1/health

# PostgreSQL
docker compose exec nocodb-postgres pg_isready -U nocodb
```

## 🔗 Integração com MCP

Após instalar o NocoDB, você pode integrá-lo com MCP:

1. Crie um token de API no NocoDB
2. Configure o MCP para usar a API do NocoDB

Exemplo de configuração `.mcp.json`:

```json
{
  "mcpServers": {
    "nocodb": {
      "type": "http",
      "url": "http://72.60.51.124:8080/api/v1",
      "headers": {
        "xc-auth": "SEU_TOKEN_API_AQUI"
      }
    }
  }
}
```

## ✅ Checklist Pós-Instalação

- [ ] NocoDB acessível via navegador
- [ ] Senha padrão alterada
- [ ] JWT secret alterado
- [ ] Senha do PostgreSQL alterada
- [ ] Firewall configurado
- [ ] Backups automáticos configurados
- [ ] (Opcional) HTTPS configurado
- [ ] (Opcional) Redis habilitado
- [ ] (Opcional) SMTP configurado

## 📞 Suporte

- Documentação: https://docs.nocodb.com/
- GitHub: https://github.com/nocodb/nocodb
- Community: https://community.nocodb.com/

---

**Boa sorte com sua instalação do NocoDB! 🚀**
