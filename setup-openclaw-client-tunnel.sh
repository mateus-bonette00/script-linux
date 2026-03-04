#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
HOST_ALIAS="openclaw-server"
SERVER_USER_HOST=""
SSH_PORT="22"
LOCAL_PORT="18789"
REMOTE_PORT="18789"
IDENTITY_FILE="${HOME}/.ssh/id_ed25519_openclaw"
COPY_KEY="true"
INSTALL_OPENCLAW_IF_MISSING="true"
CONFIGURE_REMOTE="false"
REMOTE_TOKEN=""

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
  ./setup-openclaw-client-tunnel.sh --server <usuario@ip-ou-host> [opcoes]

Obrigatorio:
  --server <usuario@ip-ou-host>   Ex.: mateus@192.168.0.20

Opcoes:
  --alias <nome>                  Alias no ~/.ssh/config (padrao: openclaw-server)
  --ssh-port <n>                  Porta SSH do servidor (padrao: 22)
  --local-port <n>                Porta local no notebook (padrao: 18789)
  --remote-port <n>               Porta do OpenClaw no servidor (padrao: 18789)
  --identity-file <path>          Chave ssh (padrao: ~/.ssh/id_ed25519_openclaw)
  --no-copy-key                   Nao roda ssh-copy-id automaticamente
  --skip-openclaw-install         Nao instala OpenClaw no notebook, mesmo se faltar
  --configure-openclaw-remote     Configura OpenClaw local para usar gateway remoto
  --remote-token <token>          Token do gateway remoto (usado com --configure-openclaw-remote)
  -h, --help                      Mostra ajuda

Exemplos:
  ./setup-openclaw-client-tunnel.sh --server mateus@192.168.0.20
  ./setup-openclaw-client-tunnel.sh --server mateus@192.168.0.20 --configure-openclaw-remote --remote-token TOKEN
EOF
}

trap 'err "Falha na linha ${LINENO}: ${BASH_COMMAND}"' ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER_USER_HOST="${2:-}"
      shift 2
      ;;
    --alias)
      HOST_ALIAS="${2:-}"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="${2:-}"
      shift 2
      ;;
    --local-port)
      LOCAL_PORT="${2:-}"
      shift 2
      ;;
    --remote-port)
      REMOTE_PORT="${2:-}"
      shift 2
      ;;
    --identity-file)
      IDENTITY_FILE="${2:-}"
      shift 2
      ;;
    --no-copy-key)
      COPY_KEY="false"
      shift
      ;;
    --skip-openclaw-install)
      INSTALL_OPENCLAW_IF_MISSING="false"
      shift
      ;;
    --configure-openclaw-remote)
      CONFIGURE_REMOTE="true"
      shift
      ;;
    --remote-token)
      REMOTE_TOKEN="${2:-}"
      shift 2
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

if [[ -z "${SERVER_USER_HOST}" ]]; then
  err "Informe --server <usuario@ip-ou-host>"
  usage
  exit 1
fi

if [[ ! "${SSH_PORT}" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
  err "SSH porta invalida: ${SSH_PORT}"
  exit 1
fi

if [[ ! "${LOCAL_PORT}" =~ ^[0-9]+$ ]] || (( LOCAL_PORT < 1 || LOCAL_PORT > 65535 )); then
  err "Local porta invalida: ${LOCAL_PORT}"
  exit 1
fi

if [[ ! "${REMOTE_PORT}" =~ ^[0-9]+$ ]] || (( REMOTE_PORT < 1 || REMOTE_PORT > 65535 )); then
  err "Remote porta invalida: ${REMOTE_PORT}"
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  err "ssh nao encontrado. Instale: sudo apt-get install openssh-client"
  exit 1
fi

SSH_USER="${SERVER_USER_HOST%@*}"
SSH_HOST="${SERVER_USER_HOST#*@}"

if [[ -z "${SSH_USER}" || -z "${SSH_HOST}" || "${SSH_USER}" == "${SSH_HOST}" ]]; then
  err "Formato de --server invalido. Use usuario@host"
  exit 1
fi

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if [[ ! -f "${IDENTITY_FILE}" ]]; then
  log "Gerando chave SSH em ${IDENTITY_FILE}..."
  ssh-keygen -t ed25519 -f "${IDENTITY_FILE}" -N "" -C "openclaw-client@$(hostname)"
else
  log "Chave SSH ja existe: ${IDENTITY_FILE}"
fi

SSH_CONFIG_FILE="${HOME}/.ssh/config"
if [[ ! -f "${SSH_CONFIG_FILE}" ]]; then
  touch "${SSH_CONFIG_FILE}"
fi
chmod 600 "${SSH_CONFIG_FILE}"

START_MARK="# >>> openclaw tunnel ${HOST_ALIAS} >>>"
END_MARK="# <<< openclaw tunnel ${HOST_ALIAS} <<<"

TMP_CFG="$(mktemp)"
awk -v start="${START_MARK}" -v end="${END_MARK}" '
  $0 == start {skip=1; next}
  $0 == end {skip=0; next}
  !skip {print}
' "${SSH_CONFIG_FILE}" > "${TMP_CFG}"

cat >> "${TMP_CFG}" <<EOF
${START_MARK}
Host ${HOST_ALIAS}
  HostName ${SSH_HOST}
  User ${SSH_USER}
  Port ${SSH_PORT}
  IdentityFile ${IDENTITY_FILE}
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
  ExitOnForwardFailure yes
  LocalForward ${LOCAL_PORT} 127.0.0.1:${REMOTE_PORT}
${END_MARK}
EOF

mv "${TMP_CFG}" "${SSH_CONFIG_FILE}"

if [[ "${COPY_KEY}" == "true" ]]; then
  log "Copiando chave publica para servidor (pode pedir senha SSH)..."
  ssh-copy-id -i "${IDENTITY_FILE}.pub" -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" || \
    warn "Nao foi possivel copiar a chave automaticamente. Rode manualmente: ssh-copy-id -i ${IDENTITY_FILE}.pub -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST}"
else
  warn "Pulando ssh-copy-id por --no-copy-key."
fi

if ! command -v openclaw >/dev/null 2>&1; then
  if [[ "${INSTALL_OPENCLAW_IF_MISSING}" == "true" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
      warn "curl nao encontrado. Nao foi possivel instalar OpenClaw automaticamente."
    else
      log "OpenClaw nao encontrado. Instalando no notebook..."
      curl -fsSL https://openclaw.ai/install.sh | bash || warn "Falha ao instalar OpenClaw automaticamente."
    fi

    # Tentativa de atualizar PATH da sessao atual quando instalacao foi via npm global.
    if ! command -v openclaw >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      export PATH="$(npm prefix -g)/bin:${PATH}"
    fi
  else
    warn "OpenClaw ausente e instalacao automatica desativada (--skip-openclaw-install)."
  fi
fi

if [[ "${CONFIGURE_REMOTE}" == "true" ]]; then
  if ! command -v openclaw >/dev/null 2>&1; then
    err "openclaw nao encontrado no notebook. Sem ele, nao da para configurar gateway remoto."
    err "Instale manualmente ou remova --skip-openclaw-install."
    exit 1
  else
    log "Configurando OpenClaw local para gateway remoto via tunnel..."
    openclaw config set gateway.mode remote || warn "Falha ao setar gateway.mode remote."
    openclaw config set gateway.remote.url "ws://127.0.0.1:${LOCAL_PORT}" || warn "Falha ao setar gateway.remote.url."

    if [[ -n "${REMOTE_TOKEN}" ]]; then
      openclaw config set gateway.remote.token "${REMOTE_TOKEN}" || warn "Falha ao setar gateway.remote.token."
    else
      warn "Token nao informado. Use --remote-token para configurar gateway.remote.token."
      warn "Voce tambem pode definir depois com:"
      warn "openclaw config set gateway.remote.token <TOKEN>"
    fi
  fi
fi

cat <<EOF

============================================
Notebook pronto para tunnel OpenClaw.
============================================

1) Teste SSH:
   ssh ${HOST_ALIAS}

2) Suba o tunnel:
   ssh -N ${HOST_ALIAS}

3) Abra no navegador:
   http://127.0.0.1:${LOCAL_PORT}/

4) (Opcional) Tunnel em background:
   ssh -fN ${HOST_ALIAS}

5) (Opcional) Validar OpenClaw remoto:
   openclaw health

Se ainda nao tiver token remoto configurado:
  openclaw config set gateway.remote.token <TOKEN_DO_SERVIDOR>
EOF
