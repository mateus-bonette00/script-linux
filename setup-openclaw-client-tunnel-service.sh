#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
HOST_ALIAS="openclaw-server"
SERVICE_NAME="openclaw-tunnel"
ENABLE_LINGER="false"
RESTART_SEC="5"

info() {
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
  ./setup-openclaw-client-tunnel-service.sh [opcoes]

Opcoes:
  --host-alias <nome>     Host do ~/.ssh/config (padrao: openclaw-server)
  --service-name <nome>   Nome da unit sem .service (padrao: openclaw-tunnel)
  --restart-sec <seg>     Delay de restart em segundos (padrao: 5)
  --enable-linger         Mantem service user-level ativa mesmo sem login
  -h, --help              Mostra ajuda

Exemplos:
  ./setup-openclaw-client-tunnel-service.sh
  ./setup-openclaw-client-tunnel-service.sh --host-alias openclaw-server --enable-linger
EOF
}

trap 'err "Falha na linha ${LINENO}: ${BASH_COMMAND}"' ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-alias)
      HOST_ALIAS="${2:-}"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="${2:-}"
      shift 2
      ;;
    --restart-sec)
      RESTART_SEC="${2:-}"
      shift 2
      ;;
    --enable-linger)
      ENABLE_LINGER="true"
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

if [[ -z "${HOST_ALIAS}" ]]; then
  err "--host-alias nao pode ser vazio."
  exit 1
fi

if [[ -z "${SERVICE_NAME}" ]]; then
  err "--service-name nao pode ser vazio."
  exit 1
fi

if [[ ! "${RESTART_SEC}" =~ ^[0-9]+$ ]]; then
  err "--restart-sec deve ser inteiro nao negativo."
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  err "systemctl nao encontrado."
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  err "ssh nao encontrado. Instale openssh-client."
  exit 1
fi

SSH_CONFIG="${HOME}/.ssh/config"
if [[ ! -f "${SSH_CONFIG}" ]]; then
  err "Arquivo ~/.ssh/config nao encontrado. Rode primeiro setup-openclaw-client-tunnel.sh."
  exit 1
fi

if ! ssh -G "${HOST_ALIAS}" >/dev/null 2>&1; then
  err "Host alias '${HOST_ALIAS}' nao encontrado/valido no ~/.ssh/config."
  err "Rode setup-openclaw-client-tunnel.sh com --alias ${HOST_ALIAS}."
  exit 1
fi

UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_FILE="${UNIT_DIR}/${SERVICE_NAME}.service"

mkdir -p "${UNIT_DIR}"

cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=OpenClaw SSH Tunnel (${HOST_ALIAS})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ssh -N ${HOST_ALIAS}
Restart=always
RestartSec=${RESTART_SEC}
TimeoutStopSec=10

[Install]
WantedBy=default.target
EOF

if [[ "${ENABLE_LINGER}" == "true" ]]; then
  info "Ativando linger para usuario ${USER}..."
  sudo loginctl enable-linger "${USER}" || warn "Nao foi possivel ativar linger."
fi

info "Recarregando systemd --user..."
systemctl --user daemon-reload

info "Habilitando e iniciando ${SERVICE_NAME}.service..."
systemctl --user enable --now "${SERVICE_NAME}.service"

STATUS="$(systemctl --user is-active "${SERVICE_NAME}.service" || true)"
ENABLED="$(systemctl --user is-enabled "${SERVICE_NAME}.service" || true)"

cat <<EOF

============================================
Servico criado com sucesso.
============================================

Unit file:
${UNIT_FILE}

Status:
- active: ${STATUS}
- enabled: ${ENABLED}

Comandos uteis:
- Ver status:
  systemctl --user status ${SERVICE_NAME}.service
- Ver logs em tempo real:
  journalctl --user -u ${SERVICE_NAME}.service -f
- Reiniciar:
  systemctl --user restart ${SERVICE_NAME}.service
- Parar:
  systemctl --user stop ${SERVICE_NAME}.service
- Desabilitar:
  systemctl --user disable ${SERVICE_NAME}.service
EOF
