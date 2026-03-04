#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
UBUNTU_TARGET_VERSION="24.04"

info() {
  printf '\n[INFO] %s\n' "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*" >&2
}

error() {
  printf '\n[ERRO] %s\n' "$*" >&2
}

trap 'error "Falha na linha ${LINENO}: ${BASH_COMMAND}"' ERR

if [[ "${EUID}" -eq 0 ]]; then
  error "Execute este script com usuario normal (sem sudo)."
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  error "Nao foi possivel ler /etc/os-release."
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  warn "Sistema detectado: ${ID:-desconhecido}. Este script foi feito para Ubuntu."
fi

if [[ "${VERSION_ID:-}" != "${UBUNTU_TARGET_VERSION}" ]]; then
  warn "Versao detectada: ${VERSION_ID:-desconhecida}. Recomendado: ${UBUNTU_TARGET_VERSION}."
fi

UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}"
CURRENT_ARCH="$(dpkg --print-architecture)"

info "Solicitando permissao sudo..."
sudo -v

APT_UPDATED=0

mark_apt_dirty() {
  APT_UPDATED=0
}

apt_update() {
  if [[ "${APT_UPDATED}" -eq 0 ]]; then
    info "Atualizando indices do apt..."
    sudo apt-get update
    APT_UPDATED=1
  fi
}

apt_install() {
  apt_update
  info "Instalando via apt: $*"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_install_optional() {
  apt_update
  local pkg
  local packages=()
  for pkg in "$@"; do
    if apt-cache show "${pkg}" >/dev/null 2>&1; then
      packages+=("${pkg}")
    else
      warn "Pacote opcional indisponivel e sera ignorado: ${pkg}"
    fi
  done

  if [[ "${#packages[@]}" -gt 0 ]]; then
    apt_install "${packages[@]}"
  fi
}

install_snap_pkg() {
  local name="$1"
  shift || true

  if snap list "${name}" >/dev/null 2>&1; then
    info "Snap ja instalado: ${name}"
    return
  fi

  info "Instalando snap: ${name} $*"
  sudo snap install "${name}" "$@"
}

setup_base_dependencies() {
  apt_install \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    unzip \
    zip \
    snapd
}

setup_docker_repo() {
  info "Configurando repositorio oficial do Docker..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=${CURRENT_ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  mark_apt_dirty
}

setup_pgadmin_repo() {
  info "Configurando repositorio do pgAdmin4..."
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/packages-pgadmin-org.gpg
  echo \
    "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${UBUNTU_CODENAME} pgadmin4 main" \
    | sudo tee /etc/apt/sources.list.d/pgadmin4.list >/dev/null
  mark_apt_dirty
}

setup_ngrok_repo() {
  info "Configurando repositorio do ngrok..."
  curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
    | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
  mark_apt_dirty
}

setup_cloudflared_repo() {
  info "Configurando repositorio do cloudflared..."
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo \
    "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared ${UBUNTU_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  mark_apt_dirty
}

install_base_dev_packages() {
  apt_install \
    build-essential \
    make \
    cmake \
    ninja-build \
    pkg-config \
    clang \
    clang-format \
    gdb \
    valgrind \
    git \
    git-lfs \
    jq \
    tree \
    htop \
    ripgrep \
    fd-find \
    fzf \
    tmux \
    zsh \
    ffmpeg \
    p7zip-full \
    shellcheck \
    shfmt \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    pipx \
    openjdk-17-jdk \
    maven \
    gradle \
    postgresql-client \
    libpq-dev \
    sqlite3 \
    default-mysql-client \
    redis-tools

  apt_install_optional gcc-13 g++-13 gcc-14 g++-14
}

install_dotnet_sdk() {
  apt_update
  if apt-cache show dotnet-sdk-8.0 >/dev/null 2>&1; then
    apt_install dotnet-sdk-8.0
    return
  fi

  warn ".NET 8 nao encontrado no apt padrao. Adicionando repositorio Microsoft..."
  local ms_deb="/tmp/packages-microsoft-prod.deb"
  curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -o "${ms_deb}"
  sudo dpkg -i "${ms_deb}"
  rm -f "${ms_deb}"
  mark_apt_dirty
  apt_install dotnet-sdk-8.0
}

install_docker_stack() {
  apt_update
  if apt-cache show docker-ce >/dev/null 2>&1; then
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    warn "docker-ce nao encontrado. Usando fallback docker.io + docker-compose-v2."
    apt_install docker.io docker-compose-v2
  fi

  sudo systemctl enable --now docker || warn "Nao foi possivel habilitar/iniciar o servico Docker automaticamente."

  if id -nG "${USER}" | grep -qw docker; then
    info "Usuario ja pertence ao grupo docker."
  else
    info "Adicionando usuario ao grupo docker..."
    sudo usermod -aG docker "${USER}"
    warn "Abra uma nova sessao (logout/login) para usar Docker sem sudo."
  fi
}

install_cloud_and_db_tools() {
  apt_install ngrok cloudflared
  apt_install pgadmin4-desktop pgadmin4-web
  apt_install apache2

  if [[ -n "${PGADMIN_SETUP_EMAIL:-}" && -n "${PGADMIN_SETUP_PASSWORD:-}" ]]; then
    info "Tentando configurar pgAdmin4 Web em modo nao interativo..."
    if ! sudo env PGADMIN_SETUP_EMAIL="${PGADMIN_SETUP_EMAIL}" \
      PGADMIN_SETUP_PASSWORD="${PGADMIN_SETUP_PASSWORD}" \
      /usr/pgadmin4/bin/setup-web.sh --yes; then
      warn "Falha no setup automatico do pgAdmin4 Web. Rode manualmente: sudo /usr/pgadmin4/bin/setup-web.sh"
    fi
  else
    warn "pgAdmin4 Web instalado, mas nao configurado. Para configurar depois: sudo /usr/pgadmin4/bin/setup-web.sh"
  fi
}

install_aws_cli_v2() {
  local aws_arch=""
  case "$(uname -m)" in
    x86_64) aws_arch="x86_64" ;;
    aarch64 | arm64) aws_arch="aarch64" ;;
    *)
      warn "Arquitetura nao suportada para instalador oficial do AWS CLI v2: $(uname -m)"
      return
      ;;
  esac

  info "Instalando/atualizando AWS CLI v2..."
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o "${tmp_dir}/awscliv2.zip"
  unzip -q "${tmp_dir}/awscliv2.zip" -d "${tmp_dir}"
  sudo "${tmp_dir}/aws/install" --update
  rm -rf "${tmp_dir}"
}

setup_snap_runtime() {
  sudo systemctl enable --now snapd.socket || true

  if [[ ! -e /snap && -d /var/lib/snapd/snap ]]; then
    sudo ln -s /var/lib/snapd/snap /snap || true
  fi

  install_snap_pkg core
}

install_google_chrome() {
  if snap info google-chrome >/dev/null 2>&1; then
    install_snap_pkg google-chrome
    return
  fi

  warn "Snap google-chrome nao encontrado no Snap Store. Instalando .deb oficial do Google Chrome."

  if [[ "${CURRENT_ARCH}" != "amd64" ]]; then
    warn "Google Chrome .deb oficial disponivel apenas para amd64. Pulando instalacao do Chrome."
    return
  fi

  local chrome_deb="/tmp/google-chrome-stable_current_amd64.deb"
  curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "${chrome_deb}"
  sudo apt-get install -y "${chrome_deb}"
  rm -f "${chrome_deb}"
}

install_desktop_snaps() {
  install_snap_pkg code --classic
  install_snap_pkg discord
  install_snap_pkg opera
  install_snap_pkg obs-studio
  install_google_chrome
}

install_nvm_node_and_frontend_tooling() {
  if [[ ! -d "${HOME}/.nvm" ]]; then
    info "Instalando NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  else
    info "NVM ja instalado."
  fi

  export NVM_DIR="${HOME}/.nvm"
  # shellcheck disable=SC1090
  if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    source "${NVM_DIR}/nvm.sh"
  else
    warn "Nao foi possivel carregar nvm.sh."
    return
  fi

  info "Instalando Node LTS e Current com NVM..."
  nvm install --lts
  nvm install node
  nvm alias default 'lts/*'
  nvm use default

  info "Instalando pacotes globais npm (frontend + tooling)..."
  npm install -g \
    npm@latest \
    pnpm \
    yarn \
    typescript \
    ts-node \
    nodemon \
    @angular/cli \
    create-react-app \
    create-vite
}

install_sdkman_and_jvm_tooling() {
  if [[ ! -d "${HOME}/.sdkman" ]]; then
    info "Instalando SDKMAN!..."
    curl -fsSL "https://get.sdkman.io" | bash
  else
    info "SDKMAN! ja instalado."
  fi

  if [[ -f "${HOME}/.sdkman/etc/config" ]]; then
    sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "${HOME}/.sdkman/etc/config" || true
  fi

  # shellcheck disable=SC1091
  if [[ -s "${HOME}/.sdkman/bin/sdkman-init.sh" ]]; then
    source "${HOME}/.sdkman/bin/sdkman-init.sh"
  else
    warn "Nao foi possivel carregar SDKMAN."
    return
  fi

  info "Instalando candidatos basicos via SDKMAN (java, kotlin, maven, gradle)..."
  sdk install java || warn "Nao foi possivel instalar java via SDKMAN automaticamente."
  sdk install kotlin || warn "Nao foi possivel instalar kotlin via SDKMAN automaticamente."
  sdk install maven || warn "Nao foi possivel instalar maven via SDKMAN automaticamente."
  sdk install gradle || warn "Nao foi possivel instalar gradle via SDKMAN automaticamente."
}

print_summary() {
  cat <<'EOF'

============================================
Setup concluido.
============================================

Itens principais instalados/configurados:
- Base dev: build-essential, Python 3, Git/Git LFS, OpenJDK 17, banco CLI, utilitarios
- Docker + Docker Compose
- AWS CLI v2
- ngrok + cloudflared
- pgAdmin4 (desktop/web) + PostgreSQL client
- .NET 8 SDK
- NVM + Node (LTS e current) + npm/pnpm/yarn + Angular/React tooling
- SDKMAN! + candidatos JVM
- Snaps: VS Code, Discord, Opera, OBS Studio (Chrome via snap quando disponivel)

Pos-instalacao recomendada:
1) Feche e abra o terminal (ou faca logout/login) para grupos e perfis de shell.
2) Verifique Docker sem sudo: docker run hello-world
3) Se nao configurou pgAdmin Web automaticamente:
   sudo /usr/pgadmin4/bin/setup-web.sh

EOF
}

main() {
  info "Iniciando setup completo de desenvolvimento (versao ${SCRIPT_VERSION})..."
  setup_base_dependencies

  setup_docker_repo
  setup_pgadmin_repo
  setup_ngrok_repo
  setup_cloudflared_repo

  install_base_dev_packages
  install_dotnet_sdk
  install_docker_stack
  install_cloud_and_db_tools
  install_aws_cli_v2

  setup_snap_runtime
  install_desktop_snaps

  install_nvm_node_and_frontend_tooling
  install_sdkman_and_jvm_tooling

  if command -v git-lfs >/dev/null 2>&1; then
    git lfs install || true
  fi

  print_summary
}

main "$@"
