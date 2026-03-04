# Guia Completo: Desktop Ubuntu 24.04 como Servidor + Notebook Ubuntu 24.04 como Central de Desenvolvimento

> **Assumindo que...**
> - Seu **desktop** (maquina secundaria) roda Ubuntu 24.04 e ficara ligado na rede.
> - Seu **notebook** (maquina principal) roda Ubuntu 24.04 e sera o ponto central de administracao.
> - Voce quer hospedar varios projetos no desktop, incluindo **Open Claw**.
> - Voce pode usar um dominio (opcional), por exemplo `meuservidor.seudominio.com`.
> - Quando houver duvida sobre Open Claw (porta/imagem/env), este guia traz trilhas adaptaveis.

---

## Sumario

- [1. Visao geral da arquitetura](#1-visao-geral-da-arquitetura)
- [2. Sequencia ideal de execucao (ordem recomendada)](#2-sequencia-ideal-de-execucao-ordem-recomendada)
- [3. Preparacao inicial do servidor (desktop)](#3-preparacao-inicial-do-servidor-desktop)
  - [3.1 Atualizar sistema, firmware e reiniciar](#31-atualizar-sistema-firmware-e-reiniciar)
  - [3.2 Hostname, timezone e NTP](#32-hostname-timezone-e-ntp)
  - [3.3 Criar usuario administrativo (nao-root)](#33-criar-usuario-administrativo-nao-root)
  - [3.4 Pacotes essenciais de operacao](#34-pacotes-essenciais-de-operacao)
- [4. Rede e IP fixo](#4-rede-e-ip-fixo)
  - [4.1 Descobrir IP atual](#41-descobrir-ip-atual)
  - [4.2 Reservar IP no roteador (recomendado)](#42-reservar-ip-no-roteador-recomendado)
  - [4.3 Alternativa com Netplan (manual)](#43-alternativa-com-netplan-manual)
- [5. SSH seguro do notebook para o servidor](#5-ssh-seguro-do-notebook-para-o-servidor)
  - [5.1 Gerar chave no notebook](#51-gerar-chave-no-notebook)
  - [5.2 Copiar chave para o servidor](#52-copiar-chave-para-o-servidor)
  - [5.3 Endurecer configuracao do SSH (boas praticas)](#53-endurecer-configuracao-do-ssh-boas-praticas)
  - [5.4 Validar antes de fechar sua sessao](#54-validar-antes-de-fechar-sua-sessao)
- [6. Firewall, Fail2ban e atualizacoes automaticas](#6-firewall-fail2ban-e-atualizacoes-automaticas)
  - [6.1 UFW: abrir so o necessario](#61-ufw-abrir-so-o-necessario)
  - [6.2 Fail2ban: bloquear forca bruta](#62-fail2ban-bloquear-forca-bruta)
  - [6.3 unattended-upgrades](#63-unattended-upgrades)
- [7. Desenvolvimento remoto pelo notebook](#7-desenvolvimento-remoto-pelo-notebook)
  - [7.1 VS Code Remote SSH (passo a passo com cliques)](#71-vs-code-remote-ssh-passo-a-passo-com-cliques)
  - [7.2 Alternativas rapidas](#72-alternativas-rapidas)
- [8. Hospedagem multi-aplicacao: padrao recomendado](#8-hospedagem-multi-aplicacao-padrao-recomendado)
  - [8.1 Instalar Docker e Compose (repo oficial)](#81-instalar-docker-e-compose-repo-oficial)
  - [8.2 Estrutura de diretorios no servidor](#82-estrutura-de-diretorios-no-servidor)
  - [8.3 Padrao de .env, secrets e permissoes](#83-padrao-de-env-secrets-e-permissoes)
- [9. Reverse proxy e HTTPS](#9-reverse-proxy-e-https)
  - [9.1 Recomendacao principal: Caddy](#91-recomendacao-principal-caddy)
  - [9.2 Opcao alternativa: Nginx](#92-opcao-alternativa-nginx)
- [10. Deploy de projetos no servidor](#10-deploy-de-projetos-no-servidor)
- [11. Monitoramento, logs e backup](#11-monitoramento-logs-e-backup)
  - [11.1 Comandos de observabilidade do dia a dia](#111-comandos-de-observabilidade-do-dia-a-dia)
  - [11.2 Logs e rotacao](#112-logs-e-rotacao)
  - [11.3 Backup com rsync + cron](#113-backup-com-rsync--cron)
  - [11.4 Extra: Prometheus + Grafana (opcional)](#114-extra-prometheus--grafana-opcional)
- [12. Open Claw no servidor (trilha detalhada)](#12-open-claw-no-servidor-trilha-detalhada)
  - [12.1 Checklist de informacoes necessarias](#121-checklist-de-informacoes-necessarias)
  - [12.2 Trilha A (recomendada): Open Claw via Docker Compose](#122-trilha-a-recomendada-open-claw-via-docker-compose)
  - [12.3 Trilha B: Open Claw sem Docker (systemd)](#123-trilha-b-open-claw-sem-docker-systemd)
  - [12.4 Como programar Open Claw do notebook](#124-como-programar-open-claw-do-notebook)
  - [12.5 Portas e endpoints do Open Claw](#125-portas-e-endpoints-do-open-claw)
- [13. Acesso externo com seguranca](#13-acesso-externo-com-seguranca)
  - [13.1 Recomendado: VPN (Tailscale)](#131-recomendado-vpn-tailscale)
  - [13.2 Se insistir em expor na internet](#132-se-insistir-em-expor-na-internet)
- [14. Checklists finais](#14-checklists-finais)
  - [14.1 Checklist Servidor pronto](#141-checklist-servidor-pronto)
  - [14.2 Checklist Open Claw pronto](#142-checklist-open-claw-pronto)
- [15. Troubleshooting (erros comuns)](#15-troubleshooting-erros-comuns)
- [16. Anexos (templates)](#16-anexos-templates)

---

## 1. Visao geral da arquitetura

### Objetivo
Ter um fluxo profissional onde:
- Desktop = servidor de execucao (apps, APIs, Open Claw, proxy, backups).
- Notebook = estacao de comando (SSH, VS Code Remote SSH, Git, deploy).

### Topologia recomendada

```text
Notebook (Ubuntu 24.04)
  |  SSH (chave), VS Code Remote SSH, Git
  v
Desktop Servidor (Ubuntu 24.04)
  |- /srv/apps/<app>
  |- /srv/openclaw
  |- Docker + Compose
  |- Caddy/Nginx (HTTPS)
  |- UFW + Fail2ban + backups
```

> **Por que?** Separar "onde programa" de "onde roda" reduz risco de quebrar seu ambiente principal e facilita operar servicos 24/7.

---

## 2. Sequencia ideal de execucao (ordem recomendada)

1. Preparar servidor (update, usuario admin, SSH, firewall).
2. Garantir acesso SSH por chave a partir do notebook.
3. Instalar stack de hospedagem (Docker/Compose + proxy HTTPS).
4. Definir estrutura de diretorios e padrao de deploy.
5. Subir Open Claw (Docker recomendado).
6. Configurar monitoramento, logs, backup e manutencao automatica.
7. (Opcional) Abrir acesso externo seguro com VPN.

---

## 3. Preparacao inicial do servidor (desktop)

## 3.1 Atualizar sistema, firmware e reiniciar

### Objetivo
Comecar com base atualizada e estavel.

### Comandos (no servidor)

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean
```

Firmware (quando suportado):

```bash
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

Reinicie:

```bash
sudo reboot
```

### Saida esperada (exemplo curto)
- `0 upgraded, 0 newly installed...` (ou lista de pacotes atualizados).
- `No upgrades for device firmware` (se nao houver firmware novo).

### Validacao

```bash
sudo apt update
```

Sem erros de repositores = OK.

---

## 3.2 Hostname, timezone e NTP

### Objetivo
Padronizar identificacao e horario para logs/deploy.

### Comandos

```bash
# Exemplo hostname:
sudo hostnamectl set-hostname srv-desktop

# Timezone:
timedatectl list-timezones | grep -i sao_paulo
sudo timedatectl set-timezone America/Sao_Paulo

# Conferir:
hostnamectl
timedatectl status
```

### Saida esperada
- `Static hostname: srv-desktop`
- `Time zone: America/Sao_Paulo`
- `System clock synchronized: yes`

### Validacao

```bash
date
timedatectl show -p NTPSynchronized --value
```

`yes` em NTP = OK.

---

## 3.3 Criar usuario administrativo (nao-root)

### Objetivo
Evitar administrar servidor com root.

### Comandos

```bash
# Se ainda nao existir:
sudo adduser opsadmin
sudo usermod -aG sudo opsadmin
```

Teste:

```bash
su - opsadmin
sudo -v
```

### Validacao

```bash
id opsadmin
```

Verifique grupo `sudo`.

> **Atencao:** Nao desabilite root/login por senha no SSH antes de validar acesso por chave com seu usuario admin.

---

## 3.4 Pacotes essenciais de operacao

### Objetivo
Instalar ferramentas base de seguranca e diagnostico.

### Comandos

```bash
sudo apt update
sudo apt install -y \
  openssh-server ufw fail2ban unattended-upgrades \
  ca-certificates curl wget gnupg lsb-release software-properties-common \
  git vim nano tmux htop jq tree unzip zip \
  net-tools iproute2 dnsutils \
  rsync logrotate
```

Ativar SSH:

```bash
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

### Validacao

```bash
ss -tulpn | grep ':22'
```

Deve exibir `sshd` escutando.

---

## 4. Rede e IP fixo

## 4.1 Descobrir IP atual

### Comando

```bash
hostname -I
ip -br a
```

Exemplo: `192.168.1.50`.

---

## 4.2 Reservar IP no roteador (recomendado)

### Objetivo
Evitar quebrar conectividade com configuracao manual local.

### Onde clicar (generico)
1. Abra o painel do roteador (normalmente `192.168.0.1` ou `192.168.1.1`).
2. Entre em **LAN / DHCP / Address Reservation**.
3. Ache o MAC do desktop (use `ip link` no servidor).
4. Crie reserva para IP fixo (ex.: `192.168.1.50`).
5. Reinicie conexao do servidor.

### Validacao
Reinicie servidor e confira se IP permanece igual:

```bash
hostname -I
```

---

## 4.3 Alternativa com Netplan (manual)

> **Atencao:** so use se voce sabe sua topologia. Erro aqui pode derrubar acesso remoto.

### Descobrir interface

```bash
ip -br a
```

Exemplo de arquivo `/etc/netplan/01-static.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      dhcp4: no
      addresses:
        - 192.168.1.50/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

Aplicar:

```bash
sudo netplan generate
sudo netplan try
# se estiver ok
sudo netplan apply
```

---

## 5. SSH seguro do notebook para o servidor

## 5.1 Gerar chave no notebook

### Objetivo
Autenticacao forte sem senha no SSH.

### Comandos (no notebook)

```bash
ssh-keygen -t ed25519 -C "notebook-to-srv-desktop" -f ~/.ssh/id_ed25519_srvdesktop
```

### Saida esperada
- Arquivos criados:
  - `~/.ssh/id_ed25519_srvdesktop`
  - `~/.ssh/id_ed25519_srvdesktop.pub`

---

## 5.2 Copiar chave para o servidor

### Comando (no notebook)

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_srvdesktop.pub opsadmin@192.168.1.50
```

Teste:

```bash
ssh -i ~/.ssh/id_ed25519_srvdesktop opsadmin@192.168.1.50
```

### Validacao
Entrou sem pedir senha do usuario remoto (pode pedir passphrase da chave local) = OK.

---

## 5.3 Endurecer configuracao do SSH (boas praticas)

### Objetivo
Reduzir superficie de ataque.

### Editar no servidor

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F-%H%M)
sudo nano /etc/ssh/sshd_config
```

Trecho recomendado:

```text
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
AllowUsers opsadmin
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
```

> **Trade-off porta SSH customizada:** mudar de `22` para outra porta reduz ruido automatizado, mas **nao substitui** chave forte, firewall e fail2ban.

Validar sintaxe e reiniciar:

```bash
sudo sshd -t
sudo systemctl restart ssh
sudo systemctl status ssh --no-pager
```

---

## 5.4 Validar antes de fechar sua sessao

Abra **outro terminal no notebook** e teste:

```bash
ssh -i ~/.ssh/id_ed25519_srvdesktop opsadmin@192.168.1.50
```

Somente depois de confirmar, feche sessoes antigas.

---

## 6. Firewall, Fail2ban e atualizacoes automaticas

## 6.1 UFW: abrir so o necessario

### Objetivo
Bloquear tudo que nao for explicitamente permitido.

### Comandos (servidor)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH
sudo ufw allow 22/tcp

# Se for expor web via proxy:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

sudo ufw enable
sudo ufw status verbose
```

### Validacao
- `Status: active`
- Regras apenas para portas necessarias.

Tabela de portas recomendadas:

| Porta | Uso | Expor internet? |
|---|---|---|
| 22/tcp | SSH admin | Preferir VPN/IP whitelist |
| 80/tcp | HTTP (ACME/redirect) | Sim, se usar HTTPS publico |
| 443/tcp | HTTPS | Sim, se app publico |
| 18789/tcp | Open Claw (exemplo) | Nao, manter interno/proxy |
| 3000/8000/etc | Apps internas | Nao, manter interno |

---

## 6.2 Fail2ban: bloquear forca bruta

### Comandos

```bash
sudo systemctl enable --now fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.d/sshd.local
```

Exemplo `/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
```

Aplicar:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

---

## 6.3 unattended-upgrades

### Objetivo
Aplicar updates de seguranca automaticamente.

### Comandos

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
sudo systemctl status unattended-upgrades --no-pager
```

Opcional: arquivo de periodicidade:

```bash
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

Conteudo:

```text
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

---

## 7. Desenvolvimento remoto pelo notebook

## 7.1 VS Code Remote SSH (passo a passo com cliques)

### Objetivo
Programar no notebook e executar no servidor sem copiar arquivo manualmente.

### Passos na interface (notebook)
1. Abra o VS Code.
2. Clique no icone **Extensions** (barra lateral esquerda).
3. Procure `Remote - SSH` (Microsoft) e clique em **Install**.
4. Pressione `Ctrl+Shift+P`.
5. Execute `Remote-SSH: Add New SSH Host...`.
6. Digite:
   ```text
   ssh -i ~/.ssh/id_ed25519_srvdesktop opsadmin@192.168.1.50
   ```
7. Selecione `~/.ssh/config`.
8. `Ctrl+Shift+P` -> `Remote-SSH: Connect to Host...` -> escolha o host.
9. No servidor remoto, abra pasta:
   - `/srv/openclaw`
   - `/srv/apps/<app>`

### O que esperar
- Canto inferior esquerdo do VS Code mostra `SSH: <host>`.
- Terminal integrado executa comandos no servidor remoto.

### Validacao
No terminal do VS Code (remoto):

```bash
hostname
pwd
```

Deve mostrar hostname do **servidor**.

---

## 7.2 Alternativas rapidas

- **JetBrains Gateway**: IDE remota (bom para projetos grandes).
- **tmux + vim/neovim** via SSH: leve e robusto.
- **code-server**: VS Code no navegador (exige hardening extra).

---

## 8. Hospedagem multi-aplicacao: padrao recomendado

## 8.1 Instalar Docker e Compose (repo oficial)

### Objetivo
Padronizar deploys e isolamento de servicos.

### Comandos (servidor)

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Permissao sem sudo (usuario admin):

```bash
sudo usermod -aG docker opsadmin
newgrp docker
docker run hello-world
```

### Validacao

```bash
docker version
docker compose version
```

---

## 8.2 Estrutura de diretorios no servidor

### Objetivo
Organizar apps, logs e backup.

### Comandos

```bash
sudo mkdir -p /srv/apps
sudo mkdir -p /srv/openclaw
sudo mkdir -p /srv/backups
sudo mkdir -p /var/log/apps

sudo chown -R opsadmin:opsadmin /srv/apps /srv/openclaw /srv/backups
sudo chmod -R 775 /srv/apps /srv/openclaw /srv/backups
```

Estrutura recomendada:

```text
/srv/apps/
  app1/
  app2/
/srv/openclaw/
/srv/backups/
/var/log/apps/
```

---

## 8.3 Padrao de .env, secrets e permissoes

### Boas praticas
- Nunca commitar `.env` com segredos.
- Use `.env.example` no Git.
- Permissoes de segredos:

```bash
chmod 600 .env
```

- Para producao, prefira:
  - Docker secrets (Swarm/K8s) ou
  - `/etc/<app>/<app>.env` com owner root e grupo especifico.

---

## 9. Reverse proxy e HTTPS

## 9.1 Recomendacao principal: Caddy

> **Por que Caddy?** Configuracao simples e HTTPS automatico por padrao.

### Instalar Caddy

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

### Exemplo `/etc/caddy/Caddyfile`

```caddy
meuservidor.seudominio.com {
  encode gzip
  reverse_proxy 127.0.0.1:3000
}

api.seudominio.com {
  reverse_proxy 127.0.0.1:8000
}

openclaw.seudominio.com {
  reverse_proxy 127.0.0.1:18789
}
```

Aplicar:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy --no-pager
```

### Validacao

```bash
curl -I https://openclaw.seudominio.com
```

Esperado: resposta `HTTP/2 200` ou `302` com certificado valido.

---

## 9.2 Opcao alternativa: Nginx

Use Nginx se voce precisa de tuning fino (rate limit complexo, WAF extra, etc.).

### Exemplo minimo de server block

```nginx
server {
    listen 80;
    server_name openclaw.seudominio.com;

    location / {
        proxy_pass http://127.0.0.1:18789;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

HTTPS via Certbot:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d openclaw.seudominio.com
```

---

## 10. Deploy de projetos no servidor

### Fluxo base recomendado

1. No notebook: codigo, commit e push no GitHub.
2. No servidor: pull e deploy controlado.

### Exemplo de deploy manual

```bash
cd /srv/apps/app1
git fetch --all
git checkout main
git pull --ff-only
docker compose pull
docker compose up -d --remove-orphans
docker compose ps
```

### Com migracoes (exemplo)

```bash
docker compose run --rm app ./migrate.sh
docker compose up -d
```

### CI opcional (GitHub Actions + SSH deploy)

> **Atencao:** Use chave deploy dedicada e acesso minimo. Nao reutilize sua chave pessoal.

Exemplo `.github/workflows/deploy.yml`:

```yaml
name: Deploy App1

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy over SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            set -e
            cd /srv/apps/app1
            git pull --ff-only
            docker compose pull
            docker compose up -d --remove-orphans
```

---

## 11. Monitoramento, logs e backup

## 11.1 Comandos de observabilidade do dia a dia

```bash
uptime
df -h
free -m
top
htop
```

Rede/portas:

```bash
ss -tulpn
sudo lsof -i -P -n | head
```

---

## 11.2 Logs e rotacao

Logs de servicos:

```bash
sudo journalctl -u ssh -n 100 --no-pager
sudo journalctl -u caddy -n 100 --no-pager
```

Logs Docker:

```bash
docker compose logs -f --tail=200
docker logs --tail=200 -f nome_container
```

Rotacao custom (exemplo):

Arquivo `/etc/logrotate.d/apps-custom`:

```text
/var/log/apps/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
```

Testar:

```bash
sudo logrotate -d /etc/logrotate.conf
```

---

## 11.3 Backup com rsync + cron

### Objetivo
Backup regular de codigo, configs e dados persistentes.

Script `/usr/local/bin/backup-server.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/srv/backups"
STAMP="$(date +%F_%H%M%S)"
DEST="${DEST_BASE}/${STAMP}"

mkdir -p "${DEST}"

rsync -a --delete /srv/apps/ "${DEST}/apps/"
rsync -a --delete /srv/openclaw/ "${DEST}/openclaw/"
rsync -a /etc/caddy/Caddyfile "${DEST}/configs/" || true
rsync -a /etc/ssh/sshd_config "${DEST}/configs/" || true

# Mantem apenas os ultimos 14 backups
cd "${DEST_BASE}"
ls -1dt */ | tail -n +15 | xargs -r rm -rf
```

Permissoes:

```bash
sudo chmod +x /usr/local/bin/backup-server.sh
```

Cron diario:

```bash
sudo crontab -e
```

Adicione:

```cron
0 2 * * * /usr/local/bin/backup-server.sh >> /var/log/backup-server.log 2>&1
```

### Validacao

```bash
sudo /usr/local/bin/backup-server.sh
ls -lah /srv/backups
tail -n 50 /var/log/backup-server.log
```

> **Dica:** Idealmente replique backup para disco externo, NAS ou storage remoto.

---

## 11.4 Extra: Prometheus + Grafana (opcional)

Se quiser observabilidade maior:
- Prometheus + Node Exporter + Grafana via Docker Compose.
- Comece simples com alertas de disco, RAM e CPU.

---

## 12. Open Claw no servidor (trilha detalhada)

## 12.1 Checklist de informacoes necessarias

Como pode haver variacoes de release/instalacao, confirme:

- Nome da imagem Docker oficial (se houver).
- Porta HTTP interna do Open Claw.
- Variaveis obrigatorias (`API_KEY`, `JWT_SECRET`, etc.).
- Banco/Redis externo necessario?
- Caminhos de persistencia (dados, logs, cache).
- Endpoint de healthcheck (`/health`, `/ready`, etc.).

> **Assumindo neste guia:** Open Claw responde em `127.0.0.1:18789` no servidor.

---

## 12.2 Trilha A (recomendada): Open Claw via Docker Compose

### Objetivo
Subir Open Claw com reinicio automatico e persistencia.

### Passo 1: preparar pasta

```bash
sudo mkdir -p /srv/openclaw
sudo chown -R opsadmin:opsadmin /srv/openclaw
cd /srv/openclaw
```

### Passo 2: criar `.env`

Arquivo `/srv/openclaw/.env`:

```bash
# Ajuste para a imagem oficial que voce usar:
OPENCLAW_IMAGE=ghcr.io/SEU_ORG/openclaw:latest

# Portas:
OPENCLAW_PORT_HOST=18789
OPENCLAW_PORT_CONTAINER=18789

# Ambiente:
OPENCLAW_ENV=production
OPENCLAW_LOG_LEVEL=info

# Secrets (exemplos):
OPENCLAW_SECRET_KEY=troque-para-uma-chave-forte
OPENCLAW_ADMIN_EMAIL=admin@seudominio.com
OPENCLAW_ADMIN_PASSWORD=troque-para-uma-senha-forte
```

Proteja o arquivo:

```bash
chmod 600 /srv/openclaw/.env
```

### Passo 3: criar `docker-compose.yml`

Arquivo `/srv/openclaw/docker-compose.yml`:

```yaml
services:
  openclaw:
    image: ${OPENCLAW_IMAGE}
    container_name: openclaw
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "127.0.0.1:${OPENCLAW_PORT_HOST}:${OPENCLAW_PORT_CONTAINER}"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    # Ajuste healthcheck conforme a imagem:
    # healthcheck:
    #   test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:${OPENCLAW_PORT_CONTAINER}/health || exit 1"]
    #   interval: 30s
    #   timeout: 5s
    #   retries: 5
```

### Passo 4: subir

```bash
cd /srv/openclaw
docker compose pull
docker compose up -d
docker compose ps
```

### Saida esperada
- Container `openclaw` em estado `Up`.

### Validacao

```bash
curl -I http://127.0.0.1:18789
docker compose logs -f --tail=200
```

### Atualizar Open Claw

```bash
cd /srv/openclaw
docker compose pull
docker compose up -d --remove-orphans
```

### Reiniciar

```bash
docker compose restart openclaw
```

---

## 12.3 Trilha B: Open Claw sem Docker (systemd)

### Objetivo
Rodar Open Claw como servico nativo.

### Passo 1: usuario de servico

```bash
sudo adduser --system --group --home /srv/openclaw openclaw
sudo mkdir -p /srv/openclaw
sudo chown -R openclaw:openclaw /srv/openclaw
```

### Passo 2: codigo/runtime

Coloque codigo em `/srv/openclaw` e crie script de execucao:

Arquivo `/srv/openclaw/run-openclaw.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /srv/openclaw

# Exemplo generico:
# Python:
# source /srv/openclaw/.venv/bin/activate
# exec python -m openclaw

# Node:
# exec npm run start

# Binario:
exec /srv/openclaw/openclaw-server
```

Permissao:

```bash
sudo chmod +x /srv/openclaw/run-openclaw.sh
sudo chown openclaw:openclaw /srv/openclaw/run-openclaw.sh
```

### Passo 3: EnvironmentFile

Arquivo `/etc/openclaw/openclaw.env`:

```bash
OPENCLAW_ENV=production
OPENCLAW_PORT=18789
OPENCLAW_SECRET_KEY=troque-para-uma-chave-forte
```

Permissao:

```bash
sudo mkdir -p /etc/openclaw
sudo chmod 700 /etc/openclaw
sudo chmod 600 /etc/openclaw/openclaw.env
```

### Passo 4: unit systemd

Arquivo `/etc/systemd/system/openclaw.service`:

```ini
[Unit]
Description=Open Claw Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/srv/openclaw
EnvironmentFile=/etc/openclaw/openclaw.env
ExecStart=/usr/bin/env bash /srv/openclaw/run-openclaw.sh
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
```

Aplicar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw
sudo systemctl status openclaw --no-pager
```

Logs:

```bash
sudo journalctl -u openclaw -f
```

---

## 12.4 Como programar Open Claw do notebook

### Fluxo recomendado
1. Abrir VS Code Remote SSH no servidor.
2. Abrir pasta `/srv/openclaw`.
3. Trabalhar em branch:
   ```bash
   git checkout -b feat/minha-mudanca
   ```
4. Commit/push.
5. No servidor, deploy:
   - Docker: `docker compose up -d --build` (ou `pull` + `up -d`)
   - systemd: `sudo systemctl restart openclaw`
6. Validar health endpoint e logs.

---

## 12.5 Portas e endpoints do Open Claw

Tabela de referencia (placeholder):

| Item | Exemplo | Como descobrir |
|---|---|---|
| Porta interna app | `18789` | docs do app / `.env` |
| Bind local | `127.0.0.1:18789` | compose/systemd config |
| Endpoint health | `/health` | docs/logs |
| Endpoint web | `/` | browser/curl |

Comandos uteis:

```bash
# portas em uso
ss -tulpn | grep -E '18789|openclaw'

# se docker
docker compose ps
docker inspect openclaw | jq '.[0].NetworkSettings.Ports'

# teste local
curl -v http://127.0.0.1:18789/
```

---

## 13. Acesso externo com seguranca

## 13.1 Recomendado: VPN (Tailscale)

### Objetivo
Acesso remoto sem expor portas diretamente na internet.

### Instalar em servidor e notebook

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
tailscale ip -4
```

### O que esperar
- IP `100.x.y.z` para cada maquina.

### Validacao
No notebook:

```bash
ping <IP_TAILSCALE_SERVIDOR>
ssh opsadmin@<IP_TAILSCALE_SERVIDOR>
```

---

## 13.2 Se insistir em expor na internet

### Checklist minimo
- DNS A/AAAA apontando para IP publico.
- Port forward no roteador:
  - `80 -> servidor:80`
  - `443 -> servidor:443`
- **Nao** encaminhar portas internas de app (3000/8000/18789 direto).
- UFW apenas com 22/80/443 (ou 22 so por VPN).
- Fail2ban ativo.

### Rate limiting (exemplo Nginx)

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

server {
    listen 443 ssl http2;
    server_name api.seudominio.com;

    location / {
        limit_req zone=api_limit burst=20 nodelay;
        proxy_pass http://127.0.0.1:8000;
    }
}
```

> **Atencao:** Publicar sem WAF, sem observabilidade e sem patching regular aumenta risco real.

---

## 14. Checklists finais

## 14.1 Checklist Servidor pronto

- [ ] Ubuntu atualizado e reiniciado.
- [ ] Hostname/timezone/NTP corretos.
- [ ] Usuario admin (`opsadmin`) com sudo.
- [ ] SSH por chave funcionando.
- [ ] `PasswordAuthentication no` aplicado e testado.
- [ ] UFW ativo com portas minimas.
- [ ] Fail2ban ativo para SSH.
- [ ] unattended-upgrades habilitado.
- [ ] Docker + Compose funcionando.
- [ ] Estrutura `/srv/apps`, `/srv/openclaw`, `/srv/backups` criada.
- [ ] Reverse proxy (Caddy ou Nginx) funcionando com HTTPS.

## 14.2 Checklist Open Claw pronto

- [ ] Pasta `/srv/openclaw` criada e com permissao correta.
- [ ] `.env` configurado com segredos fortes.
- [ ] Open Claw subindo sem erro (Docker ou systemd).
- [ ] Healthcheck/endpoint principal responde localmente.
- [ ] Reverse proxy para Open Claw funcionando (se publico).
- [ ] Logs acessiveis (`docker logs` ou `journalctl`).
- [ ] Backup incluindo dados do Open Claw.
- [ ] Procedimento de update validado.

---

## 15. Troubleshooting (erros comuns)

| Problema | Causa provavel | Como corrigir |
|---|---|---|
| `ssh: Permission denied (publickey)` | chave nao copiada ou arquivo com permissao errada | `ssh-copy-id`, revisar `~/.ssh/authorized_keys`, `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys` |
| SSH caiu apos mudar `sshd_config` | sintaxe invalida ou regra bloqueando usuario | `sudo sshd -t`, restaurar backup `sshd_config.bak...`, reiniciar SSH |
| Sem acesso apos habilitar UFW | porta SSH nao liberada | via console local: `sudo ufw allow 22/tcp && sudo ufw reload` |
| Docker sem permissao (`permission denied /var/run/docker.sock`) | usuario fora do grupo docker | `sudo usermod -aG docker opsadmin` e novo login |
| Container sobe e cai | env faltando, porta em conflito, volume com permissao errada | `docker compose logs`, `ss -tulpn`, ajustar `.env`, corrigir `chown/chmod` |
| `bind: address already in use` | porta ocupada por outro servico | `sudo ss -tulpn | grep :PORTA` e trocar porta ou parar servico |
| HTTPS nao emite certificado | DNS incorreto, portas 80/443 fechadas, proxy fora do ar | validar DNS, abrir firewall/roteador, checar logs do Caddy/Nginx |
| VS Code Remote SSH nao conecta | host errado no `~/.ssh/config`, chave incorreta | testar SSH no terminal primeiro, depois VS Code |
| Backup vazio/incompleto | caminho incorreto ou permissao insuficiente | executar script manualmente e revisar log `/var/log/backup-server.log` |
| Open Claw indisponivel externamente | proxy nao roteando, app bind em IP errado | manter app em `127.0.0.1`, ajustar `reverse_proxy` |

---

## 16. Anexos (templates)

### Anexo A - `~/.ssh/config` no notebook

```sshconfig
Host srv-desktop
  HostName 192.168.1.50
  User opsadmin
  IdentityFile ~/.ssh/id_ed25519_srvdesktop
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

### Anexo B - Script rapido de validacao de saude do servidor

Arquivo `/usr/local/bin/server-health-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== DATE ==" && date
echo "== UPTIME ==" && uptime
echo "== DISK ==" && df -h
echo "== MEMORY ==" && free -m
echo "== DOCKER ==" && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "== SSH ==" && systemctl is-active ssh
echo "== UFW ==" && sudo ufw status | head -n 20
```

Permissao:

```bash
sudo chmod +x /usr/local/bin/server-health-check.sh
```

### Anexo C - Comandos rapidos de emergencia

```bash
# Reverter sshd_config se travar acesso (via console local)
sudo cp /etc/ssh/sshd_config.bak.YYYY-MM-DD-HHMM /etc/ssh/sshd_config
sudo systemctl restart ssh

# Abrir firewall temporariamente para diagnostico (somente em emergencia)
sudo ufw disable

# Ver ultimas falhas de boot/servicos
journalctl -p 3 -xb
```

---

## Conclusao

Com este fluxo, voce opera o desktop como servidor profissional e desenvolve com conforto no notebook, com:
- SSH seguro,
- deploy padronizado,
- hospedagem multi-app,
- Open Claw com duas trilhas de execucao,
- observabilidade e backup,
- caminho seguro para acesso externo.

Se quiser evoluir depois:
1. Adicionar ambiente `staging` separado.
2. Integrar SSO/VPN obrigatoria para administracao.
3. Automatizar deploy com rollback.

