#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
DEFAULT_PORT="18789"
PORT="${DEFAULT_PORT}"
ENABLE_LINGER="false"
SKIP_ONBOARD="false"
FORCE_TOKEN="false"

log() {
  printf '\n[INFO] %s\n' "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*" >&2
}

err() {
  printf '\n[ERRO] %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Uso:
  ./setup-openclaw-server.sh [opcoes]

Opcoes:
  --port <n>            Porta do gateway (padrao: 18789)
  --enable-linger       Ativa linger para manter service user-level apos logout
  --skip-onboard        Nao roda wizard openclaw onboard
  --force-token         Gera token com doctor mesmo se ja houver token
  -h, --help            Mostra ajuda

Exemplos:
  ./setup-openclaw-server.sh
  ./setup-openclaw-server.sh --port 18789 --enable-linger
EOF
}

trap 'err "Falha na linha ${LINENO}: ${BASH_COMMAND}"' ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --enable-linger)
      ENABLE_LINGER="true"
      shift
      ;;
    --skip-onboard)
      SKIP_ONBOARD="true"
      shift
      ;;
    --force-token)
      FORCE_TOKEN="true"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      err "Opcao invalida: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  err "Porta invalida: ${PORT}"
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  err "Execute com usuario normal (sem sudo)."
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "Sistema detectado: ${ID:-desconhecido}. Recomendado: ubuntu."
  fi
  if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    warn "Versao detectada: ${VERSION_ID:-desconhecida}. Script testado em 24.04."
  fi
fi

log "Setup OpenClaw Server v${SCRIPT_VERSION}"
log "Validando sudo..."
sudo -v

log "Instalando dependencias base..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  git \
  openssh-server

log "Garantindo SSH ativo..."
sudo systemctl enable --now ssh

if command -v openclaw >/dev/null 2>&1; then
  log "OpenClaw ja instalado em: $(command -v openclaw)"
else
  log "Instalando OpenClaw via script oficial..."
  curl -fsSL https://openclaw.ai/install.sh | bash
fi

# Atualiza PATH da sessao caso o instalador tenha colocado binario global via npm.
if ! command -v openclaw >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  export PATH="$(npm prefix -g)/bin:${PATH}"
fi

if ! command -v openclaw >/dev/null 2>&1; then
  err "Comando openclaw nao encontrado apos instalacao."
  err "Abra um novo terminal e tente novamente."
  exit 1
fi

if [[ "${SKIP_ONBOARD}" == "false" ]]; then
  log "Rodando onboarding (pode pedir entradas interativas)..."
  openclaw onboard --install-daemon
else
  log "Pulando onboarding por --skip-onboard."
  log "Tentando instalar/iniciar daemon diretamente..."
  openclaw gateway install || true
  openclaw gateway start || true
fi

log "Aplicando configuracao recomendada para acesso por tunnel (loopback/local)..."
openclaw config set gateway.mode local || warn "Falha ao setar gateway.mode local."
openclaw config set gateway.bind loopback || warn "Falha ao setar gateway.bind loopback."
openclaw config set gateway.port "${PORT}" || warn "Falha ao setar gateway.port."
openclaw gateway restart || warn "Falha ao reiniciar gateway."

if [[ "${ENABLE_LINGER}" == "true" ]]; then
  log "Ativando linger para usuario ${USER}..."
  sudo loginctl enable-linger "${USER}" || warn "Nao foi possivel ativar linger."
fi

TOKEN="$(openclaw config get gateway.auth.token 2>/dev/null || true)"

if [[ "${FORCE_TOKEN}" == "true" || -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
  log "Gerando token do gateway com doctor..."
  openclaw doctor --generate-gateway-token || warn "Nao foi possivel gerar token automaticamente."
  TOKEN="$(openclaw config get gateway.auth.token 2>/dev/null || true)"
fi

GATEWAY_STATUS="$(openclaw gateway status 2>/dev/null || true)"
if [[ -n "${GATEWAY_STATUS}" ]]; then
  printf '\n%s\n' "${GATEWAY_STATUS}"
fi

SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
if [[ -z "${SERVER_IP}" ]]; then
  SERVER_IP="<IP_DO_SERVIDOR>"
fi

cat <<EOF

============================================
OpenClaw server configurado.
============================================

Passos no notebook:
1) Copiar chave SSH:
   ssh-copy-id ${USER}@${SERVER_IP}

2) Abrir tunnel:
   ssh -N -L ${PORT}:127.0.0.1:${PORT} ${USER}@${SERVER_IP}

3) Abrir dashboard local no notebook:
   http://127.0.0.1:${PORT}/

Token atual do gateway:
${TOKEN:-<nao encontrado>}

Comandos uteis aqui no servidor:
- openclaw gateway status
- openclaw logs --follow
- openclaw config get gateway.auth.token
EOF
