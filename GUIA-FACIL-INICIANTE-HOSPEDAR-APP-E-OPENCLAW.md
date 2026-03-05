# Guia Facil (Iniciante): Hospedar App Fullstack no Desktop com Git + Script + OpenClaw

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

## 1) Estrategia recomendada (a mais facil para voce)

Em vez de montar tudo manualmente dentro do servidor, use este padrao:

1. Sua aplicacao fica em um repositorio Git (GitHub/GitLab/etc)
2. No desktop, voce clona em `~/Documentos/apps/meu-repositorio`
3. O repositorio ja tem script de deploy (`scripts/deploy.sh`)
4. Para atualizar: `git pull --ff-only` + script

Resultado:

- Menos erro manual
- Processo repetivel
- Mais facil manter e corrigir

---

## 2) Mapa mental simples (para nao se perder)

- Notebook = controle (onde voce programa e envia para Git)
- Desktop = servidor (onde app roda 24/7)

Fluxo:

1. Voce faz alteracoes no codigo (notebook)
2. Sobe para o repositorio (`git push`)
3. No desktop, puxa atualizacao (`git pull`) e roda script
4. O script recompila/substitui containers

---

## 3) Estrutura padrao do repositorio da aplicacao

Dentro do seu repositorio (`meu-repositorio`), use esta base:

```text
meu-repositorio/
  .env.example
  .gitignore
  docker-compose.yml
  /backend
  /frontend
  /scripts
    deploy.sh
    update.sh
```

Observacoes importantes:

- `.env` real nao entra no Git (segredo)
- `.env.example` entra no Git (modelo sem senha real)
- `deploy.sh` sobe/atualiza containers
- `update.sh` puxa Git e chama `deploy.sh`

Atalho para iniciar rapido com arquivos prontos deste projeto:

```bash
cp -r /home/bonette/Documentos/Softwares/script-linux/templates/app-repo/. /CAMINHO/DO/SEU/REPO/
```

Depois ajuste apenas o que for especifico do seu app (`backend`, `frontend` e `docker-compose.yml`).

---

## 4) Preparacao unica no desktop

No desktop, execute uma vez:

```bash
mkdir -p /home/bonette/Documentos/apps
```

Se quiser confirmar:

```bash
ls -la /home/bonette/Documentos/apps
```

---

## 5) Primeiro deploy completo (passo a passo)

### 5.1 Clonar repositorio no desktop

```bash
cd /home/bonette/Documentos/apps
git clone URL_DO_SEU_REPOSITORIO.git
cd meu-repositorio
```

Exemplo de URL:

- HTTPS: `https://github.com/seu-usuario/meu-repositorio.git`
- SSH: `git@github.com:seu-usuario/meu-repositorio.git`

### 5.2 Criar `.env` local

```bash
cp .env.example .env
nano .env
chmod 600 .env
```

Exemplo de `.env`:

```env
POSTGRES_DB=meuappdb
POSTGRES_USER=meuappuser
POSTGRES_PASSWORD=troque_essa_senha_forte
APP_ENV=production
BACKEND_PORT=18080
FRONTEND_PORT=13000
```

### 5.3 Dar permissao de execucao nos scripts

```bash
chmod +x scripts/deploy.sh scripts/update.sh
```

### 5.4 Rodar deploy

```bash
./scripts/deploy.sh
```

Se deu certo:

- `docker compose ps` mostra containers `Up`
- frontend responde na porta configurada
- backend responde na porta configurada

---

## 6) Atualizar app em producao (deploy futuro)

Sempre que publicar codigo novo no repositorio:

```bash
cd /home/bonette/Documentos/apps/meu-repositorio
./scripts/update.sh
```

O `update.sh` faz:

1. verifica se pasta e Git estao ok
2. roda `git pull --ff-only`
3. roda `./scripts/deploy.sh`

---

## 7) Conteudo recomendado para scripts (pronto para copiar)

Se seu repositorio ainda nao tiver scripts, use estes exatamente.

### 7.1 `scripts/deploy.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${APP_DIR}"

log() {
  printf '[deploy] %s\n' "$*"
}

fail() {
  printf '[deploy][erro] %s\n' "$*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "Docker nao encontrado."
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin nao encontrado."

compose_file=""
for file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [[ -f "${file}" ]]; then
    compose_file="${file}"
    break
  fi
done

[[ -n "${compose_file}" ]] || fail "Arquivo de compose nao encontrado."
[[ -f .env ]] || fail "Arquivo .env nao encontrado. Crie com: cp .env.example .env"

if command -v stat >/dev/null 2>&1; then
  env_perm="$(stat -c '%a' .env 2>/dev/null || true)"
  if [[ -n "${env_perm}" && "${env_perm}" -gt 600 ]]; then
    log "Aviso: permissao de .env esta ${env_perm}. Recomendado: chmod 600 .env"
  fi
fi

log "Validando docker compose"
docker compose config >/dev/null

log "Subindo containers (build + up)"
docker compose up -d --build --remove-orphans

log "Aguardando containers ficarem prontos"
timeout_seconds="${DEPLOY_TIMEOUT_SECONDS:-180}"
start_time="$(date +%s)"

while true; do
  all_ok=1

  mapfile -t ids < <(docker compose ps -q)
  [[ "${#ids[@]}" -gt 0 ]] || fail "Nenhum container foi criado."

  for id in "${ids[@]}"; do
    name="$(docker inspect --format '{{.Name}}' "${id}" | sed 's#^/##')"
    status="$(docker inspect --format '{{.State.Status}}' "${id}")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}")"

    if [[ "${status}" != "running" ]]; then
      fail "Container ${name} nao esta rodando (status=${status})."
    fi

    if [[ "${health}" == "unhealthy" ]]; then
      docker compose logs --tail=200 || true
      fail "Container ${name} esta unhealthy."
    fi

    if [[ "${health}" == "starting" ]]; then
      all_ok=0
    fi
  done

  if [[ "${all_ok}" -eq 1 ]]; then
    break
  fi

  now_time="$(date +%s)"
  elapsed="$((now_time - start_time))"

  if (( elapsed >= timeout_seconds )); then
    docker compose ps || true
    docker compose logs --tail=200 || true
    fail "Timeout aguardando healthchecks (${timeout_seconds}s)."
  fi

  sleep 3
done

log "Deploy concluido com sucesso"
docker compose ps
```

### 7.2 `scripts/update.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${APP_DIR}"

log() {
  printf '[update] %s\n' "$*"
}

fail() {
  printf '[update][erro] %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "Git nao encontrado."
[[ -d .git ]] || fail "Esta pasta nao e um repositorio Git."

if ! git diff --quiet || ! git diff --cached --quiet; then
  fail "Existem alteracoes locais. Commit/stash antes de atualizar."
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
log "Atualizando branch ${branch}"
git pull --ff-only

log "Executando deploy"
"${SCRIPT_DIR}/deploy.sh"
```

---

## 8) Expor app no servidor (Caddy)

Hoje voce nao usa dominio. Entao use HTTP local na rede.

Arquivo:

```bash
sudo nano /etc/caddy/Caddyfile
```

Modelo:

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

Testes:

```bash
curl -I http://127.0.0.1
curl -I http://127.0.0.1/api/health
```

No notebook (browser):

- `http://192.168.0.173`

Observacao:

- `handle_path /api/*` remove `/api` antes de enviar ao backend.
- Se seu backend espera `/api`, use `handle /api/*` em vez de `handle_path`.

---

## 9) Banco de dados persistente (na pratica)

No `docker-compose.yml`, o banco deve usar volume:

- `db_data:/var/lib/postgresql/data`

Isso garante:

- reiniciou container, dados continuam
- atualizou imagem, dados continuam

So perde dado se apagar volume manualmente.

---

## 10) OpenClaw no seu cenario (desktop + notebook)

Seu fluxo correto:

- OpenClaw Gateway no desktop (`127.0.0.1:18789`)
- Notebook conecta por tunnel SSH (`openclaw-tunnel.service`)
- Cliente OpenClaw do notebook usa `gateway.mode=remote`

Desktop:

```bash
openclaw gateway status
openclaw logs --follow
```

Notebook:

```bash
systemctl --user status openclaw-tunnel.service --no-pager
openclaw health
openclaw status
curl -I http://127.0.0.1:18789
```

Se falhar no notebook:

```bash
systemctl --user restart openclaw-tunnel.service
journalctl --user -u openclaw-tunnel.service -n 60 --no-pager
```

---

## 11) Rotina diaria simples

Desktop:

```bash
uptime
df -h
free -m
sudo systemctl status ssh --no-pager
sudo systemctl status caddy --no-pager
docker ps
```

Notebook:

```bash
ssh srv-desktop 'echo SSH_OK'
systemctl --user status openclaw-tunnel.service --no-pager
openclaw status
```

---

## 12) Checklist final (antes de publicar)

- [ ] Repositorio criado e versionado
- [ ] `docker-compose.yml` no repo
- [ ] `scripts/deploy.sh` e `scripts/update.sh` no repo
- [ ] `.env.example` no repo
- [ ] `.env` criado localmente no desktop (`chmod 600`)
- [ ] Deploy inicial com `./scripts/deploy.sh`
- [ ] `docker compose ps` com containers `Up`
- [ ] Caddy validado e recarregado
- [ ] Front abre no navegador
- [ ] API responde
- [ ] Banco com volume persistente
- [ ] Backup diario ativo

---

## 13) Caminho recomendado daqui pra frente

Ordem pratica:

1. Criar um app (um de cada vez)
2. Manter tudo no Git
3. Fazer deploy sempre via script
4. Repetir o mesmo padrao nos proximos apps

Esse padrao e o mais seguro e simples para voce crescer sem bagunca.
