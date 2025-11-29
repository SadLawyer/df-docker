# NocoDB Setup - Resumo Executivo

## ✅ O que foi criado

Esta configuração inclui tudo o que você precisa para instalar e gerenciar o NocoDB com PostgreSQL no seu servidor.

### Arquivos Criados

1. **`docker-compose.nocodb.yml`** - Configuração Docker Compose completa
   - NocoDB (última versão)
   - PostgreSQL 15
   - Health checks automáticos
   - Volumes persistentes

2. **`.env.nocodb.example`** - Template de variáveis de ambiente
   - Senhas e configurações
   - Exemplos de SMTP, S3, etc.

3. **`deploy-nocodb.sh`** - Script de deploy automatizado
   - Testa conexão SSH
   - Copia arquivos para o servidor
   - Inicia containers
   - Verifica status

4. **`manage-nocodb.sh`** - Script de gerenciamento
   - start, stop, restart
   - logs, status, health
   - backup, restore, update

5. **`MANUAL-INSTALL.md`** - Guia de instalação manual passo a passo
   - Para executar diretamente no servidor
   - Inclui todos os comandos necessários

6. **`NOCODB-README.md`** - Documentação completa
   - Configuração
   - Segurança
   - Troubleshooting
   - Integração com MCP

## 🚀 Como Instalar

### Opção 1: Usando o Script de Deploy (Recomendado)

Se a conexão SSH funcionar:

```bash
./deploy-nocodb.sh
```

### Opção 2: Instalação Manual (Mais Confiável)

Se houver problemas de rede/SSH:

1. Conecte-se ao servidor:
   ```bash
   ssh root@72.60.51.124
   # Senha: 4fourEVERYyoung@
   ```

2. Siga as instruções em **`MANUAL-INSTALL.md`**
   - Copie e cole os comandos
   - São apenas 8 passos simples

## 📋 Configuração Padrão

| Item | Valor |
|------|-------|
| URL de Acesso | http://72.60.51.124:8080 |
| Porta | 8080 |
| Admin Email | admin@nocodb.com |
| Admin Password | admin123 ⚠️ MUDE ISSO! |
| Database | PostgreSQL 15 |
| Database User | nocodb |
| Database Password | nocodb_secure_password_2024 |

## ⚠️ IMPORTANTE - Primeiros Passos

Após a instalação:

1. **Acesse**: http://72.60.51.124:8080
2. **Login com**:
   - Email: `admin@nocodb.com`
   - Password: `admin123`
3. **MUDE A SENHA IMEDIATAMENTE!**
4. **Crie um API Token** para integração com MCP

## 🔐 Segurança

### Checklist de Segurança

- [ ] Mudar senha do admin
- [ ] Mudar `NC_AUTH_JWT_SECRET` no docker-compose
- [ ] Mudar senha do PostgreSQL
- [ ] Configurar firewall (porta 8080)
- [ ] (Opcional) Configurar HTTPS com Nginx/Caddy
- [ ] Configurar backups automáticos

### Comandos Rápidos de Segurança

```bash
# Gerar JWT secret forte
openssl rand -base64 32

# Configurar firewall
ssh root@72.60.51.124 "ufw allow 8080/tcp && ufw reload"

# Criar backup
./manage-nocodb.sh backup
```

## 🛠️ Comandos Úteis

```bash
# Ver status
./manage-nocodb.sh status

# Ver logs
./manage-nocodb.sh logs

# Criar backup
./manage-nocodb.sh backup

# Atualizar
./manage-nocodb.sh update

# Reiniciar
./manage-nocodb.sh restart
```

## 🔗 Integração com MCP

Depois de instalar o NocoDB:

1. **Crie um API Token**:
   - Login no NocoDB
   - Account Settings → API Tokens
   - Create New Token
   - Copie o token

2. **Atualize `.mcp.json`**:
   ```json
   {
     "mcpServers": {
       "nocodb": {
         "type": "http",
         "url": "http://72.60.51.124:8080/api/v1",
         "headers": {
           "xc-auth": "SEU_TOKEN_AQUI"
         }
       }
     }
   }
   ```

3. **Teste a conexão**:
   ```bash
   curl -H "xc-auth: SEU_TOKEN" http://72.60.51.124:8080/api/v1/health
   ```

## 📚 Documentação

- **Instalação Manual**: `MANUAL-INSTALL.md`
- **Documentação Completa**: `NOCODB-README.md`
- **Configuração MCP**: `MCP-SETUP.md`
- **Docker Compose**: `docker-compose.nocodb.yml`

## 🐛 Problemas Comuns

### Não consigo conectar via SSH

Use a instalação manual. Veja `MANUAL-INSTALL.md`

### Porta 8080 não responde

```bash
# Verifique firewall
ssh root@72.60.51.124 "ufw allow 8080/tcp"

# Verifique container
./manage-nocodb.sh status
```

### Container não inicia

```bash
# Ver logs
./manage-nocodb.sh logs

# Reiniciar
./manage-nocodb.sh restart
```

### Esqueci a senha do admin

```bash
ssh root@72.60.51.124
cd /opt/nocodb
docker compose exec nocodb-postgres psql -U nocodb -d nocodb
# UPDATE nc_users SET password = crypt('nova-senha', gen_salt('bf')) WHERE email = 'admin@nocodb.com';
```

## 🎯 Próximos Passos

1. ✅ Instalar NocoDB (use `MANUAL-INSTALL.md`)
2. ✅ Fazer primeiro login
3. ✅ Mudar senha padrão
4. ✅ Criar API token
5. ✅ Configurar MCP
6. ✅ Configurar backups automáticos
7. ⚪ (Opcional) Configurar HTTPS
8. ⚪ (Opcional) Configurar domínio personalizado
9. ⚪ (Opcional) Configurar SMTP

## 📞 Recursos

- **NocoDB Docs**: https://docs.nocodb.com/
- **API Docs**: http://72.60.51.124:8080/api/v1/docs (após instalação)
- **GitHub**: https://github.com/nocodb/nocodb
- **Community**: https://community.nocodb.com/

## 💡 Dicas

1. **Sempre faça backup antes de atualizar**
   ```bash
   ./manage-nocodb.sh backup
   ```

2. **Use Redis para melhor performance**
   - Descomente seção Redis em `docker-compose.nocodb.yml`

3. **Configure HTTPS em produção**
   - Use Nginx ou Caddy com Let's Encrypt

4. **Monitore recursos**
   ```bash
   ssh root@72.60.51.124 "docker stats nocodb nocodb-postgres"
   ```

5. **Backup automático**
   - Configure cron job (veja `MANUAL-INSTALL.md`)

---

**Pronto para começar! 🚀**

Para qualquer dúvida, consulte a documentação completa em `NOCODB-README.md` ou `MANUAL-INSTALL.md`.
