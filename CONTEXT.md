# CONTEXT

## Objetivo deste arquivo
Resumo rapido do ambiente atual para continuar o trabalho de qualquer maquina (principalmente no notebook).

## Ambiente atual
- Desktop (servidor): `192.168.0.173`
- Notebook: maquina de controle (SSH + tunnel OpenClaw)
- SSH: funcionando
- UFW: ativo (22/80/443)
- Fail2ban: ativo
- Docker + Docker Compose: funcionando
- Backup com cron: configurado
- OpenClaw no desktop: instalado
- Tunnel OpenClaw no notebook (`openclaw-tunnel.service`): ativo

## Decisao operacional atual (PADRAO OFICIAL)
Nao usar `/srv/apps` neste fluxo.

Usar sempre repositorios Git em:
- `/home/bonette/Documentos/apps/<nome-do-repositorio>`

Cada app deve ter no repo:
- `docker-compose.yml`
- `.env.example`
- `scripts/deploy.sh`
- `scripts/update.sh`

No desktop, o `.env` real fica no clone local e nao vai para Git.

## Fluxo padrao de deploy
Primeiro deploy (desktop):
```bash
cd /home/bonette/Documentos/apps
git clone URL_DO_REPOSITORIO.git
cd <nome-do-repositorio>
cp .env.example .env
nano .env
chmod 600 .env
chmod +x scripts/deploy.sh scripts/update.sh
./scripts/deploy.sh
```

Atualizacao futura (desktop):
```bash
cd /home/bonette/Documentos/apps/<nome-do-repositorio>
./scripts/update.sh
```

## Caddy (exposicao local na rede)
Arquivo:
- `/etc/caddy/Caddyfile`

Modelo atual:
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

## OpenClaw no cenario atual
Arquitetura:
- Gateway OpenClaw roda no desktop em `127.0.0.1:18789`
- Notebook conecta no gateway via tunnel SSH
- Cliente do notebook usa `gateway.mode=remote`

Verificacao (desktop):
```bash
openclaw gateway status
openclaw logs --follow
```

Verificacao (notebook):
```bash
systemctl --user status openclaw-tunnel.service --no-pager
openclaw health
openclaw status
curl -I http://127.0.0.1:18789
```

## Template pronto neste projeto
Arquivos base para copiar para um novo repo de app:
- `templates/app-repo/.env.example`
- `templates/app-repo/.gitignore`
- `templates/app-repo/docker-compose.yml`
- `templates/app-repo/scripts/deploy.sh`
- `templates/app-repo/scripts/update.sh`

## Referencia principal
- `GUIA-FACIL-INICIANTE-HOSPEDAR-APP-E-OPENCLAW.md`
