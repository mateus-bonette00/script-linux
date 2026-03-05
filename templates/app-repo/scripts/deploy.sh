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
