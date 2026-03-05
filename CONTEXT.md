# CONTEXT

## Objetivo deste arquivo
Este arquivo resume o contexto atual do ambiente para continuar o trabalho quando voce estiver no notebook.

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

## Caminho padrao dos apps (DECISAO ATUAL)
Nao usar `/srv/apps` para os apps deste fluxo.

Usar sempre:
- `/home/bonette/Documentos/apps/meuapp`

Estrutura esperada:
```text
/home/bonette/Documentos/apps/meuapp/
  .env
  docker-compose.yml
  /backend
  /frontend
```

## Fluxo padrao de deploy
No desktop:
```bash
cd /home/bonette/Documentos/apps/meuapp
docker compose up -d --build
docker compose ps
docker compose logs -f --tail=100
```

Para atualizar codigo:
```bash
cd /home/bonette/Documentos/apps/meuapp
git pull --ff-only
docker compose up -d --build
docker compose ps
```

## Caddy (exposicao local na rede)
Arquivo:
- `/etc/caddy/Caddyfile`

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

Aplicar alteracoes:
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

Verificacao rapida (desktop):
```bash
openclaw gateway status
openclaw logs --follow
```

Verificacao rapida (notebook):
```bash
systemctl --user status openclaw-tunnel.service --no-pager
openclaw health
openclaw status
curl -I http://127.0.0.1:18789
```

## Comandos de saude diaria
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

## Referencia principal
Guia atualizado:
- `GUIA-FACIL-INICIANTE-HOSPEDAR-APP-E-OPENCLAW.md`
