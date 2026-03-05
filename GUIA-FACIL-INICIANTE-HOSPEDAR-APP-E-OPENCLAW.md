# Guia Facil (Iniciante): Hospedar Frontend + Backend + Banco no Desktop e usar OpenClaw

## 0) Onde voce esta agora (resumo do seu ambiente)

Pelo que voce ja fez, seu ambiente esta assim:

- Desktop (servidor): `192.168.0.173`
- SSH: funcionando
- UFW: ativo (22/80/443)
- Fail2ban: ativo
- Docker + Compose: funcionando
- Backup com cron: configurado
- OpenClaw no desktop: instalado
- Tunnel OpenClaw no notebook: ativo

Ou seja: a base do servidor ja esta pronta.

---

## 1) Mapa mental simples (**para** nunca se perder)

Pense assim:

- Notebook = **controle** (onde voce digita comandos e programa)
- Desktop = **servidor** (onde suas aplicacoes ficam rodando 24/7)

Quando voce "hospeda", significa:

1. Colocar projeto no desktop (pasta em `/home/bonette/Documentos/apps/...`)
2. Subir com Docker Compose
3. Expor com Caddy (porta 80)
4. Manter banco em volume persistente
5. Fazer backup

---

## 2) Receita padrao para qualquer app (sempre igual)

Use sempre esta estrutura no desktop:

```text
/home/bonette/Documentos/apps/meuapp/
  .env
  docker-compose.yml
  /backend
  /frontend
```

### 2.1 Criar pasta do app no desktop

```bash
mkdir -p /home/bonette/Documentos/apps/meuapp
cd /home/bonette/Documentos/apps/meuapp
```

### 2.2 Criar `.env`

```bash
nano .env
```

Exemplo inicial:

```env
POSTGRES_DB=meuappdb
POSTGRES_USER=meuappuser
POSTGRES_PASSWORD=troque_essa_senha_forte
APP_ENV=production
BACKEND_PORT=18080
FRONTEND_PORT=13000
```

Depois proteja:

```bash
chmod 600 .env
```

### 2.3 Criar `docker-compose.yml`

```bash
nano docker-compose.yml
```

Exemplo completo (frontend + backend + banco):

```yaml
services:
  db:
    image: postgres:16-alpine
    container_name: meuapp-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - appnet

  backend:
    build: ./backend
    container_name: meuapp-backend
    restart: unless-stopped
    environment:
      APP_ENV: ${APP_ENV}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "127.0.0.1:${BACKEND_PORT}:8080"
    networks:
      - appnet

  frontend:
    build: ./frontend
    container_name: meuapp-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "127.0.0.1:${FRONTEND_PORT}:80"
    networks:
      - appnet

volumes:
  db_data:

networks:
  appnet:
    driver: bridge
```

Observacao importante:

- Seu backend precisa escutar na porta `8080` dentro do container.
- Seu frontend precisa servir na porta `80` dentro do container.
- Se for diferente, ajuste no compose.

### 2.4 Subir o app

```bash
cd /home/bonette/Documentos/apps/meuapp
docker compose up -d --build
docker compose ps
docker compose logs -f --tail=100
```

Se `ps` mostrar `Up`, app esta rodando.

---

## 3) Expor app no servidor (Caddy)

Hoje voce nao usa dominio. Entao use HTTP local na rede.

### 3.1 Configuracao simples do Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

Exemplo (frontend em `/` e backend em `/api`):

```caddy
:80 {
  encode gzip

  handle_path /api/* {
    reverse_proxy 127.0.0.1:18080
  }

  handle {
    reverse_proxy 127.0.0.1:13000
  }
}
```

Aplicar:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager
```

Teste no desktop:

```bash
curl -I http://127.0.0.1
```

Teste no notebook (browser):

- `http://192.168.0.173`

---

## 4) Como fazer deploy quando atualizar seu app

Toda vez que atualizar codigo:

```bash
cd /home/bonette/Documentos/apps/meuapp
git pull --ff-only
docker compose up -d --build
docker compose ps
```

Se algo der erro:

```bash
docker compose logs -f --tail=200
```

---

## 5) Banco de dados sempre persistente

No compose acima, o banco usa volume:

- `db_data:/var/lib/postgresql/data`

Isso significa:

- se container reiniciar, dados continuam
- se atualizar imagem, dados continuam

So perde dado se voce apagar volume manualmente.

---

## 6) OpenClaw no seu cenario (desktop + notebook)

Seu fluxo correto ficou assim:

- OpenClaw Gateway roda no desktop (loopback `127.0.0.1:18789`)
- Notebook conecta por tunnel SSH (`openclaw-tunnel.service`)
- Cliente OpenClaw do notebook usa `gateway.mode=remote`

### 6.1 Comandos de verificacao (desktop)

```bash
openclaw gateway status
openclaw logs --follow
```

### 6.2 Comandos de verificacao (notebook)

```bash
systemctl --user status openclaw-tunnel.service --no-pager
openclaw health
openclaw status
curl -I http://127.0.0.1:18789
```

### 6.3 Se parar de funcionar

No notebook:

```bash
systemctl --user restart openclaw-tunnel.service
journalctl --user -u openclaw-tunnel.service -n 60 --no-pager
```

No desktop (se SSH cair):

```bash
sudo systemctl restart ssh
sudo systemctl status ssh --no-pager
```

Se der erro de token OpenClaw:

No desktop:

```bash
openclaw doctor --generate-gateway-token
jq -r '.gateway.auth.token // empty' ~/.openclaw/openclaw.json
```

No notebook (com token novo):

```bash
openclaw config set gateway.remote.token "TOKEN_NOVO"
openclaw health
```

---

## 7) Rotina diaria (simples)

No desktop:

```bash
uptime
df -h
free -m
sudo systemctl status ssh --no-pager
sudo systemctl status caddy --no-pager
docker ps
```

No notebook:

```bash
ssh srv-desktop 'echo SSH_OK'
systemctl --user status openclaw-tunnel.service --no-pager
openclaw status
```

---

## 8) Checklist rapido (sempre antes de publicar app)

- [ ] App esta em `/home/bonette/Documentos/apps/meuapp`
- [ ] `.env` criado e `chmod 600 .env`
- [ ] `docker compose up -d --build` sem erro
- [ ] `docker compose ps` com tudo `Up`
- [ ] Caddy validado e recarregado
- [ ] Front abre no navegador
- [ ] API responde
- [ ] Banco com volume persistente
- [ ] Backup diario ativo

---

## 9) Caminho recomendado para voce daqui pra frente

Ordem pratica para nunca se perder:

1. Escolher um app (um so primeiro)
2. Subir com a receita padrao deste guia
3. Validar frontend/backend/banco
4. Depois repetir o mesmo modelo nos proximos apps
5. Manter OpenClaw separado via tunnel (como ja esta)

Se voce seguir exatamente esse padrao, voce consegue hospedar qualquer projeto fullstack no seu desktop com muito menos dor de cabeca.
