# Comandos usados - Servidor Ubuntu 24 + OpenClaw (Desktop + Notebook)

Este arquivo resume os comandos executados no processo, com o objetivo de cada um.

## 1) Acesso SSH (notebook -> servidor)

- `ssh -i ~/.ssh/id_ed25519_srvdesktop opsadmin@192.168.0.173`
  - Conecta ao servidor usando chave SSH especifica.

- `ssh srv-desktop`
  - Conecta via alias definido no `~/.ssh/config`.

- `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_srvdesktop -C "notebook->srv-desktop"`
  - Gera par de chave SSH no notebook.

- `ssh-copy-id -i ~/.ssh/id_ed25519_srvdesktop.pub opsadmin@192.168.0.173`
  - Copia chave publica para login sem senha no servidor.

- `nano ~/.ssh/config`
  - Edita alias SSH (`Host srv-desktop`).

## 2) Firewall UFW

- `sudo ufw default deny incoming`
  - Bloqueia entrada por padrao.

- `sudo ufw default allow outgoing`
  - Libera saida por padrao.

- `sudo ufw allow 22/tcp`
  - Libera SSH.

- `sudo ufw allow 80/tcp`
  - Libera HTTP.

- `sudo ufw allow 443/tcp`
  - Libera HTTPS.

- `sudo ufw enable`
  - Ativa firewall.

- `sudo ufw status verbose`
  - Mostra regras e politicas ativas.

- `sudo ufw status numbered`
  - Mostra regras numeradas.

- `sudo ufw reload`
  - Recarrega regras.

## 3) Fail2ban

- `sudo systemctl enable --now fail2ban`
  - Ativa e inicia Fail2ban.

- `sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local`
  - Cria base local de configuracao.

- `sudo nano /etc/fail2ban/jail.d/sshd.local`
  - Configura jail do SSH.

- `sudo systemctl restart fail2ban`
  - Reinicia servico apos ajustes.

- `sudo fail2ban-client status`
  - Mostra jails ativas.

- `sudo fail2ban-client status sshd`
  - Mostra estado da jail SSH.

- `sudo fail2ban-client set sshd unbanip 192.168.0.165`
  - Remove ban do IP do notebook.

- `sudo systemctl is-active fail2ban`
  - Confirma se servico esta ativo.

## 4) Atualizacoes automaticas

- `sudo dpkg-reconfigure --priority=low unattended-upgrades`
  - Habilita unattended-upgrades.

- `sudo systemctl status unattended-upgrades --no-pager`
  - Verifica status do servico.

- `sudo nano /etc/apt/apt.conf.d/20auto-upgrades`
  - Ajusta periodicidade de update/upgrade automatico.

## 5) Docker e Compose

- `sudo apt update`
  - Atualiza indice de pacotes.

- `sudo apt install -y ca-certificates curl gnupg`
  - Instala dependencias para repositorio Docker.

- `sudo install -m 0755 -d /etc/apt/keyrings`
  - Cria diretorio de keyrings.

- `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null`
  - Baixa chave GPG do Docker.

- `sudo chmod a+r /etc/apt/keyrings/docker.asc`
  - Permite leitura da chave para apt.

- `echo "deb ..." | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null`
  - Adiciona repositorio oficial Docker.

- `sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
  - Instala Docker Engine + Compose plugin.

- `sudo systemctl enable --now docker`
  - Ativa e inicia Docker.

- `sudo usermod -aG docker opsadmin`
  - Adiciona usuario ao grupo docker.

- `newgrp docker`
  - Recarrega grupos na sessao atual.

- `docker run --rm hello-world`
  - Testa Docker funcionando.

- `docker version`
  - Mostra versao client/server Docker.

- `docker compose version`
  - Mostra versao do Compose plugin.

## 6) Estrutura de diretorios

- `sudo mkdir -p /srv/apps /srv/openclaw /srv/backups /var/log/apps`
  - Cria estrutura base de apps, OpenClaw, backups e logs.

- `sudo chown -R opsadmin:opsadmin /srv/apps /srv/openclaw /srv/backups`
  - Ajusta ownership das pastas de trabalho.

- `sudo chmod -R 775 /srv/apps /srv/openclaw /srv/backups`
  - Ajusta permissoes de grupo.

- `sudo chown opsadmin:opsadmin /var/log/apps`
  - Permite apps do usuario gravarem logs custom.

- `sudo chmod 775 /var/log/apps`
  - Ajusta permissao da pasta de logs custom.

## 7) Caddy (proxy local)

- `sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl`
  - Dependencias para repositorio Caddy.

- `curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg`
  - Baixa chave GPG do Caddy.

- `curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list`
  - Adiciona repositorio Caddy.

- `sudo apt update && sudo apt install -y caddy`
  - Instala Caddy.

- `sudo nano /etc/caddy/Caddyfile`
  - Edita configuracao do Caddy.

- `sudo caddy validate --config /etc/caddy/Caddyfile`
  - Valida sintaxe do Caddyfile.

- `sudo systemctl restart caddy`
  - Reinicia Caddy.

- `sudo systemctl status caddy --no-pager`
  - Verifica status do Caddy.

- `curl -I http://127.0.0.1`
  - Testa proxy HTTP local.

- `sudo ss -ltnp | grep ':80'`
  - Diagnostica conflito de porta 80.

- `sudo systemctl disable --now apache2`
  - Libera porta 80 desativando Apache.

## 8) Observabilidade e logs (passo 11)

- `uptime`
  - Mostra carga e tempo ligado.

- `df -h`
  - Mostra uso de disco.

- `free -m`
  - Mostra uso de memoria/swap.

- `ss -tulpn`
  - Mostra portas e processos escutando.

- `sudo journalctl -u ssh -n 100 --no-pager`
  - Logs recentes do SSH.

- `sudo journalctl -u caddy -n 100 --no-pager`
  - Logs recentes do Caddy.

## 9) Rotacao de logs

- `sudo nano /etc/logrotate.d/apps-custom`
  - Cria regra custom de rotacao para `/var/log/apps/*.log`.

- `sudo logrotate -d /etc/logrotate.conf`
  - Simula rotacao (debug, sem executar de fato).

## 10) Backup (rsync + cron)

- `sudo nano /usr/local/bin/backup-server.sh`
  - Cria script de backup de `/srv/apps`, `/srv/openclaw` e configs.

- `sudo chmod +x /usr/local/bin/backup-server.sh`
  - Torna script executavel.

- `sudo /usr/local/bin/backup-server.sh`
  - Executa backup manual.

- `ls -lah /srv/backups`
  - Verifica snapshots criados.

- `sudo crontab -e`
  - Agenda tarefa diaria.

- `0 2 * * * /usr/local/bin/backup-server.sh >> /var/log/backup-server.log 2>&1`
  - Linha de cron para backup diario as 02:00.

- `sudo crontab -l`
  - Confirma cron configurado.

## 11) OpenClaw no servidor (via script)

- `cd /home/mateus/Documentos/Projetos/script-linux`
  - Entra no repositorio com scripts.

- `chmod +x setup-openclaw-server.sh`
  - Permissao de execucao no script do servidor.

- `./setup-openclaw-server.sh --port 18789 --enable-linger --skip-onboard --force-token`
  - Instala/configura OpenClaw gateway no desktop (loopback + linger + token).

- `openclaw gateway status`
  - Verifica status do gateway.

- `openclaw config get gateway.auth.token`
  - Le token atual do gateway (mascarado pelo CLI).

- `jq -r '.gateway.auth.token // empty' ~/.openclaw/openclaw.json`
  - Le token real direto do arquivo JSON.

- `openclaw doctor --generate-gateway-token`
  - Gera/regenera token do gateway.

- `ss -ltnp | grep 18789`
  - Confirma servico escutando na porta 18789.

## 12) Tunnel no notebook (via scripts)

- `chmod +x setup-openclaw-client-tunnel.sh setup-openclaw-client-tunnel-service.sh`
  - Permissao de execucao nos scripts do notebook.

- `./setup-openclaw-client-tunnel.sh --server opsadmin@192.168.0.173 --alias openclaw-server --identity-file ~/.ssh/id_ed25519_srvdesktop --no-copy-key --configure-openclaw-remote --remote-token "<TOKEN>"`
  - Configura alias SSH + remote gateway no cliente OpenClaw.

- `./setup-openclaw-client-tunnel-service.sh --host-alias openclaw-server --enable-linger`
  - Cria servico `systemd --user` para tunnel permanente.

- `systemctl --user restart openclaw-tunnel.service`
  - Reinicia tunnel.

- `systemctl --user status openclaw-tunnel.service --no-pager`
  - Verifica tunnel ativo.

- `journalctl --user -u openclaw-tunnel.service -n 60 --no-pager`
  - Logs do tunnel (falhas de SSH/restart).

- `ssh -G openclaw-server | egrep '^(user|hostname|port|identityfile|localforward) '`
  - Debug da configuracao efetiva do alias SSH.

- `ssh openclaw-server 'echo SSH_OK'`
  - Teste rapido de SSH via alias.

## 13) Ajustes de conectividade feitos

- `sudo systemctl enable --now ssh`
  - Reativou SSH no desktop quando houve `connection refused`.

- `sudo systemctl restart ssh`
  - Reiniciou daemon SSH.

- `sudo ss -ltnp | grep ':22'`
  - Confirmou sshd escutando na porta 22.

- `sudo fail2ban-client set sshd unbanip 192.168.0.165`
  - Desbaniu IP do notebook.

- `sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'EOF' ... EOF`
  - Reescreveu jail SSH com `ignoreip` para notebook.

- `sudo systemctl restart fail2ban`
  - Aplicou nova configuracao fail2ban.

## 14) Validacao final

- `ssh -o ConnectTimeout=5 -i ~/.ssh/id_ed25519_srvdesktop opsadmin@192.168.0.173 'echo SSH_OK'`
  - Confirmou SSH funcional novamente.

- `openclaw health`
  - Teste de saude do cliente OpenClaw.

- `openclaw status`
  - Estado geral; mostrou gateway remoto alcancavel.

- `curl -I http://127.0.0.1:18789`
  - Confirmou dashboard OpenClaw respondendo `HTTP/1.1 200 OK` via tunnel.
