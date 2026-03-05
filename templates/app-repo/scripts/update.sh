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
