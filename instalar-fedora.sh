#!/usr/bin/env bash
#
# instalar-fedora.sh
# ---------------------------------------------------------------------------
# Provisiona uma instalação limpa do Fedora Workstation (x86_64).
#
# Estratégia de instalação (preferência decrescente):
#   1. Pacotes dos repositórios oficiais do Fedora (dnf).
#   2. Repositórios RPM oficiais de terceiros (VS Code, Chrome, Edge)
#      e pacotes RPM avulsos (Zoom).
#      Vantagem: atualizam junto com "dnf upgrade".
#   3. Flatpak/Flathub apenas para o que não tem pacote RPM confiável
#      (Postman, WinBox, FDM, DBeaver, AnyDesk, Ferdium, Extension Manager).
#
# Recursos:
#   - Autorização gráfica (janela de senha) quando não há terminal.
#   - Logs e cache de RPM em ~/.local, fora do repositório.
#   - Tratamento de erro real, contagem de falhas e resumo final.
#   - Idempotente: pode ser reexecutado sem quebrar.
#   - Auto-atualização opcional a partir de URL do repositório Git.
#
# Uso:
#   ./instalar-fedora.sh [opções]
#
# Opções:
#   -y, --yes         Não perguntar nada (modo não interativo).
#   -n, --dry-run     Mostra o que faria, sem alterar o sistema.
#   --no-upgrade      Pula o "dnf upgrade" (só instala o que falta).
#   --no-self-update  Não tenta atualizar o script pelo Git.
#   --only <grupo>    Executa só um grupo:
#                     dnf|repos|rpm|flatpak|dev|cleanup
#   -h, --help        Mostra esta ajuda.
#
# Requisitos: Fedora Workstation (x86_64), internet, usuário com sudo.
# ---------------------------------------------------------------------------

set -uo pipefail

# ===========================================================================
# CONFIGURAÇÃO
# ===========================================================================

# --- Pacotes dos repositórios oficiais do Fedora ---------------------------
DNF_PACKAGES=(
    tilix              # terminal emulado
    flameshot          # captura de tela
    git
    curl
    wget
    gnome-tweaks
    gnome-browser-connector
    flatpak
    keepassxc          # gerenciador de senhas
    remmina            # cliente VNC/RDP/SSH (VNC/RDP/SSH built-in, sem plugins separados)
    ulauncher          # launcher de aplicativos
)

# --- Repositórios RPM oficiais de terceiros --------------------------------
# Formato: "Nome|URL_da_chave|URL_do_repo|nome_do_arquivo_repo|pacotes"
THIRD_PARTY_REPOS=(
    "Visual Studio Code|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/yumrepos/vscode|vscode.repo|code"
    "Microsoft Edge|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/yumrepos/edge|microsoft-edge.repo|microsoft-edge-stable"
)

# Google Chrome instala o próprio repositório via RPM
CHROME_RPM_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"

# --- Pacotes RPM avulsos ----------------------------------------------------
# Formato: "Nome|URL|arquivo_local|pacote_rpm"
DIRECT_RPMS=(
    "Zoom|https://zoom.us/client/latest/zoom_x86_64.rpm|zoom.rpm|zoom"
)

# --- Aplicativos via Flatpak (Flathub) -------------------------------------
FLATPAK_APPS=(
    com.mattjakeman.ExtensionManager
    com.getpostman.Postman
    com.mikrotik.WinBox
    org.freedownloadmanager.Manager
    io.dbeaver.DBeaverCommunity
    com.anydesk.Anydesk
    org.ferdium.Ferdium
)

# --- Ferramentas de desenvolvimento ----------------------------------------
NVM_VERSION="v0.40.8"          # versão do nvm a instalar
NVM_NODE_VERSION="lts"         # versão do Node a instalar após o nvm ("" pula)

# .NET SDK — instale os canais que quiser (side-by-side). Ex.: (8.0 9.0 10.0)
DOTNET_CHANNELS=(10.0 8.0)

# Arquivo único com as variáveis de ambiente, carregado pelo ~/.bashrc, ~/.zshrc, ~/.profile
ENV_FILE="$HOME/.config/instalar-fedora/env.sh"

# --- Auto-atualização do script pelo repositório Git -----------------------
REPO_RAW_URL=""
SELF_UPDATE="yes"

# --- Caminhos --------------------------------------------------------------
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/instalar-fedora"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/instalar-fedora"
LOG_DIR="$DATA_HOME/logs"
RPM_DIR="$CACHE_HOME/rpm"
SUMMARY="$LOG_DIR/summary.log"

# --- Cores -----------------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-0}" -eq 0 ]; then
    C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_ERR=$'\033[31m'
    C_WARN=$'\033[33m'; C_INFO=$'\033[36m'; C_BOLD=$'\033[1m'
    else
    C_RESET=""; C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_BOLD=""
fi

# --- Contadores ------------------------------------------------------------
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILED_ITEMS=()

# --- Spinner ---------------------------------------------------------------
SPINNER_PID=""
SPINNER_TEXT=""

# --- Flags -----------------------------------------------------------------
ASSUME_YES=0
DRY_RUN=0
DO_UPGRADE=1
ONLY=""
NO_COLOR=0
VERBOSE=0

# Ambiente não interativo para o dnf: evita prompts que travam a instalação
DNF_ENV=(
    env
    DEBIAN_FRONTEND=noninteractive
    DEBCONF_NONINTERACTIVE_SEEN=true
    NEEDRESTART_MODE=a
)
DNF_OPTS=(
    -y
    --setopt=install_weak_deps=False
    --setopt=tsflags=nodocs
    --allowerasing
)

# ===========================================================================
# FUNÇÕES BÁSICAS
# ===========================================================================

_spinner() {
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while :; do
        for (( i=0; i<${#frames}; i++ )); do
            printf '\r%s%s%s %s' "$C_INFO" "${frames:i:1}" "$C_RESET" "${SPINNER_TEXT:-...}" >&2
            sleep 0.1
        done
    done 2>/dev/null
}

spinner_start() {
    [ -t 2 ] || return 0
    [ -n "$SPINNER_PID" ] && return 0
    SPINNER_TEXT="${1:-trabalhando...}"
    _spinner &
    SPINNER_PID=$!
}

spinner_stop() {
    [ -n "$SPINNER_PID" ] || return 0
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""
    printf '\r%-*s\r' "$(tput cols 2>/dev/null || echo 80)" "" >&2
}

info()  { spinner_stop; printf '%s\n' "${C_INFO}$*${C_RESET}"; }
warn()  { spinner_stop; printf '%s\n' "${C_WARN}$*${C_RESET}" >&2; }
err()   { spinner_stop; printf '%s\n' "${C_ERR}$*${C_RESET}" >&2; }
title() { spinner_stop; printf '\n%s\n' "${C_BOLD}==> $*${C_RESET}"; }

record() {
    spinner_stop
    local status="$1" label="$2"
    local ts
    ts="$(date '+%H:%M:%S')"
    case "$status" in
        OK)   OK_COUNT=$((OK_COUNT + 1))
              printf '%s[%s] [OK]  %s%s\n' "$C_OK" "$ts" "$C_RESET" "$label" ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1))
              printf '%s[%s] [SKIP]%s %s\n' "$C_WARN" "$ts" "$C_RESET" "$label" ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED_ITEMS+=("$label")
              printf '%s[%s] [FAIL]%s %s\n' "$C_ERR" "$ts" "$C_RESET" "$label" ;;
    esac
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$label" >> "$SUMMARY"
}

confirm() {
    local question="$1"
    [ "$ASSUME_YES" -eq 1 ] && return 0
    spinner_stop
    if [ -t 0 ]; then
        local reply
        read -r -p "${C_WARN}$question [s/N] ${C_RESET}" reply
        case "$reply" in [sSyY]*) return 0 ;; *) return 1 ;; esac
    elif command -v zenity >/dev/null 2>&1; then
        zenity --question --title="Instalação Fedora" --width=420 --text="$question" 2>/dev/null
    else
        return 0
    fi
}

run_cmd() {
    local label="$1" logfile="$2"; shift 2
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "$label (dry-run): $*"
        return 0
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        "$@" 2>&1 | tee -a "$logfile"
        if [ "${PIPESTATUS[0]:-1}" -eq 0 ]; then
            record OK "$label"; return 0
        fi
        record FAIL "$label (veja $logfile)"; return 1
    fi
    spinner_start "$label"
    if "$@" >>"$logfile" 2>&1; then
        record OK "$label"; return 0
    fi
    record FAIL "$label (veja $logfile)"; return 1
}

have()        { command -v "$1" >/dev/null 2>&1; }
pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }
flatpak_installed() { flatpak info "$1" >/dev/null 2>&1; }

# ===========================================================================
# AUTORIZAÇÃO (janela de senha)
# ===========================================================================

SUDO=(sudo)
setup_sudo() {
    if [ -t 0 ] && [ -t 1 ]; then
        SUDO=(sudo); return
    fi
    if [ -x /usr/local/bin/sudo-askpass ]; then
        export SUDO_ASKPASS="/usr/local/bin/sudo-askpass"
        SUDO=(sudo -A)
    else
        warn "Helper gráfico de sudo não encontrado; usando sudo normal."
        SUDO=(sudo)
    fi
}

prime_sudo() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    if sudo -n true 2>/dev/null; then
        info "Credencial de sudo já em cache."
        return 0
    fi
    title "Solicitando autorização (senha do sudo)"
    if "${SUDO[@]}" -v; then
        record OK "Autorização concedida (válida conforme timestamp_timeout)"
    else
        record FAIL "Falha na autorização do sudo"
        return 1
    fi
}

ensure_askpass() {
    [ -x /usr/local/bin/sudo-askpass ] && return 0
    have pkexec || { warn "pkexec ausente; sem janela de senha."; return 1; }

    title "Instalando helper gráfico de sudo (janela de senha)"
    local tmp; tmp="$(mktemp -d)"
    cat > "$tmp/sudo-askpass" <<'ASKPASS'
#!/bin/bash
set -u
prompt="${1:-Senha:}"
clean="$(printf '%s' "$prompt" | sed -e 's/^\[[^]]*\] *//' | tr -d '\r' | tail -n1)"
[ -z "$clean" ] && clean="Senha:"
if command -v zenity >/dev/null 2>&1; then
    exec zenity --password --title="Autenticação necessária" --timeout=180 --width=400 2>/dev/null
elif command -v kdialog >/dev/null 2>&1; then
    exec kdialog --title "Autenticação necessária" --password "$clean"
elif [ -x /usr/libexec/openssh/gnome-ssh-askpass ]; then
    exec /usr/libexec/openssh/gnome-ssh-askpass "$clean"
fi
echo "sudo-askpass: nenhum helper gráfico disponível." >&2
exit 1
ASKPASS
    cat > "$tmp/install.sh" <<'INSTALL'
#!/bin/bash
set -euo pipefail
install -m 0755 "$1" /usr/local/bin/sudo-askpass
cat > /etc/profile.d/sudo-askpass.sh <<'EOF'
export SUDO_ASKPASS="/usr/local/bin/sudo-askpass"
EOF
chmod 0644 /etc/profile.d/sudo-askpass.sh
cat > /etc/sudoers.d/sudo-askpass <<'EOF'
Defaults env_keep += "SUDO_ASKPASS"
EOF
chmod 0440 /etc/sudoers.d/sudo-askpass
chown root:root /etc/sudoers.d/sudo-askpass
visudo -cf /etc/sudoers.d/sudo-askpass >/dev/null
grep -q '^Path askpass /usr/local/bin/sudo-askpass' /etc/sudo.conf || \
    printf '\nPath askpass /usr/local/bin/sudo-askpass\n' >> /etc/sudo.conf
INSTALL
    chmod +x "$tmp/install.sh" "$tmp/sudo-askpass"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Instalação do helper de sudo (dry-run)"
    elif pkexec /bin/bash "$tmp/install.sh" "$tmp/sudo-askpass" >>"$LOG_DIR/askpass.log" 2>&1; then
        record OK "Helper gráfico de sudo instalado"
    else
        record FAIL "Helper gráfico de sudo (veja $LOG_DIR/askpass.log)"
    fi
    rm -rf "$tmp"
}

# ===========================================================================
# AUTO-ATUALIZAÇÃO
# ===========================================================================

self_update() {
    [ "$SELF_UPDATE" = "yes" ] || { record SKIP "Auto-atualização desativada"; return; }
    [ -n "$REPO_RAW_URL" ] || { record SKIP "Auto-atualização (REPO_RAW_URL não configurada)"; return; }
    have curl || { record FAIL "Auto-atualização (curl ausente)"; return; }

    title "Verificando atualização do script"
    local tmp; tmp="$(mktemp)"
    if curl -fsSL "$REPO_RAW_URL" -o "$tmp" 2>>"$LOG_DIR/self_update.log"; then
        if ! cmp -s "$tmp" "$SCRIPT_PATH"; then
            cp -f "$tmp" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"
            record OK "Script atualizado a partir do repositório"
        else
            record OK "Script já está atualizado"
        fi
    else
        record FAIL "Falha ao baixar atualização (veja $LOG_DIR/self_update.log)"
    fi
    rm -f "$tmp"
}

# ===========================================================================
# PRÉ-REQUISITOS
# ===========================================================================

preflight() {
    title "Verificando pré-requisitos"

    if [ "$(id -u)" -eq 0 ]; then
        err "Não execute como root; o script usa sudo quando necessário."
        exit 1
    fi

    # Permite pular verificação de SO no dry-run (para testes em outros sistemas)
    if [ "$DRY_RUN" -eq 0 ]; then
        if [ -r /etc/os-release ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            if [ "${ID:-}" = "fedora" ]; then
                record OK "Sistema: Fedora ${VERSION_ID:-?}"
            else
                record FAIL "Sistema não é Fedora (${ID:-?}); abortando."
                exit 1
            fi
        fi

        if [ "$(uname -m)" != "x86_64" ]; then
            record FAIL "Arquitetura não suportada: $(uname -m) (requer x86_64)"
            exit 1
        fi
    else
        record SKIP "Verificação de SO/arquitetura (dry-run)"
    fi

    if have curl || have wget; then record OK "Ferramenta de download disponível"
    else record FAIL "Sem curl/wget para downloads"; fi

    if [ "$DRY_RUN" -eq 0 ]; then
        if have dnf; then record OK "dnf disponível"
        else record FAIL "dnf não encontrado"; exit 1; fi
    else
        record SKIP "Verificação de dnf (dry-run)"
    fi
}

# ===========================================================================
# ETAPAS
# ===========================================================================

dnf_refresh() {
    title "Atualizando metadados (dnf check-update)"
    confirm "Executar 'dnf check-update'?" || { record SKIP "dnf check-update (recusado)"; return; }
    run_cmd "dnf check-update" "$LOG_DIR/dnf_check_update.log" "${SUDO[@]}" dnf check-update
}

dnf_upgrade() {
    title "Atualização de pacotes (dnf upgrade)"
    [ "$DO_UPGRADE" -eq 1 ] || { record SKIP "dnf upgrade desativado"; return; }
    confirm "Executar 'dnf upgrade'? Isso pode demorar." || { record SKIP "dnf upgrade (recusado)"; return; }
    run_cmd "dnf upgrade" "$LOG_DIR/dnf_upgrade.log" \
        "${DNF_ENV[@]}" "${SUDO[@]}" dnf upgrade "${DNF_OPTS[@]}"
}

dnf_install() {
    title "Pacotes oficiais do Fedora"
    local missing=() p
    for p in "${DNF_PACKAGES[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        record SKIP "Pacotes oficiais (todos já instalados)"; return
    fi
    info "Faltando: ${#missing[@]} pacote(s)"
    confirm "Instalar ${#missing[@]} pacote(s) via dnf?" || { record SKIP "Pacotes oficiais (recusado)"; return; }

    for p in "${missing[@]}"; do
        run_cmd "$p" "$LOG_DIR/dnf_install.log" \
            "${DNF_ENV[@]}" "${SUDO[@]}" dnf install "${DNF_OPTS[@]}" "$p"
    done
}

add_third_party_repos() {
    title "Repositórios RPM de terceiros"
    [ "${#THIRD_PARTY_REPOS[@]}" -eq 0 ] && { record SKIP "Sem repositórios de terceiros"; return; }

    local entry name key_url repo_url repo_file pkgs
    for entry in "${THIRD_PARTY_REPOS[@]}"; do
        IFS='|' read -r name key_url repo_url repo_file pkgs <<< "$entry"

        local repo_path="/etc/yum.repos.d/$repo_file"
        local installed=0
        for p in $pkgs; do pkg_installed "$p" && installed=1; done
        if [ "$installed" -eq 1 ]; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Repositório $name (dry-run): $pkgs"; continue
        fi
        confirm "Adicionar repositório e instalar $name?" || { record SKIP "$name (recusado)"; continue; }

        # Importar chave
        run_cmd "Importar chave $name" "$LOG_DIR/repo_${name// /_}_key.log" \
            "${SUDO[@]}" rpm --import "$key_url"

        # Criar arquivo .repo
        local repo_content
        repo_content="[$name]
name=$name
baseurl=$repo_url
enabled=1
gpgcheck=1
gpgkey=$key_url
repo_gpgcheck=1
type=rpm-md
metadata_expire=6h"

        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Criar $repo_path (dry-run)"
        else
            printf '%s\n' "$repo_content" | "${SUDO[@]}" tee "$repo_path" >/dev/null
            record OK "Repositório $name configurado em $repo_path"
        fi

        run_cmd "dnf makecache ($name)" "$LOG_DIR/dnf_makecache.log" \
            "${SUDO[@]}" dnf makecache

        # shellcheck disable=SC2086
        run_cmd "Instalação $name" "$LOG_DIR/repo_${name// /_}_install.log" \
            "${DNF_ENV[@]}" "${SUDO[@]}" dnf install "${DNF_OPTS[@]}" $pkgs
    done
}

install_chrome() {
    title "Google Chrome (RPM direto com repositório)"
    if pkg_installed "google-chrome-stable"; then
        record SKIP "Google Chrome (já instalado)"; return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Google Chrome (dry-run)"; return
    fi
    confirm "Instalar Google Chrome?" || { record SKIP "Google Chrome (recusado)"; return; }

    local tmp_rpm; tmp_rpm="$(mktemp --suffix=.rpm)"
    run_cmd "Download Google Chrome" "$LOG_DIR/chrome_download.log" \
        curl -fL --retry 3 -o "$tmp_rpm" "$CHROME_RPM_URL"

    run_cmd "Instalação Google Chrome" "$LOG_DIR/chrome_install.log" \
        "${DNF_ENV[@]}" "${SUDO[@]}" dnf install "${DNF_OPTS[@]}" "$tmp_rpm"

    rm -f "$tmp_rpm"
}

install_direct_rpms() {
    title "Pacotes RPM avulsos"
    [ "${#DIRECT_RPMS[@]}" -eq 0 ] && { record SKIP "Pacotes RPM avulsos (lista vazia)"; return; }

    local entry name url file pkg dest
    for entry in "${DIRECT_RPMS[@]}"; do
        IFS='|' read -r name url file pkg <<< "$entry"
        dest="$RPM_DIR/$file"

        if pkg_installed "$pkg"; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Instalação $name (dry-run)"; continue
        fi
        confirm "Baixar e instalar $name?" || { record SKIP "$name (recusado)"; continue; }

        if [ ! -s "$dest" ]; then
            spinner_start "Baixando $name..."
            if have curl; then
                curl -fL --retry 3 -o "$dest" "$url" >>"$LOG_DIR/rpm_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/rpm_download.log)"; continue; }
            else
                wget -qO "$dest" "$url" >>"$LOG_DIR/rpm_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/rpm_download.log)"; continue; }
            fi
        fi

        run_cmd "Instalação $name" "$LOG_DIR/rpm_install.log" \
            "${DNF_ENV[@]}" "${SUDO[@]}" dnf install "${DNF_OPTS[@]}" "$dest"
    done
}

flatpak_setup() {
    title "Flatpak e Flathub"
    have flatpak || { record FAIL "Flatpak não instalado; pulando"; return 1; }
    confirm "Adicionar o repositório Flathub?" || { record SKIP "Flathub (recusado)"; return; }
    run_cmd "Repositório Flathub" "$LOG_DIR/flatpak_remote.log" \
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    run_cmd "Atualização Flatpak" "$LOG_DIR/flatpak_update.log" \
        flatpak update --user --noninteractive -y
}

flatpak_install() {
    title "Aplicativos Flatpak"
    [ "${#FLATPAK_APPS[@]}" -eq 0 ] && { record SKIP "Flatpak (lista vazia)"; return; }
    have flatpak || { record FAIL "Flatpak ausente; aplicativos não instalados"; return; }

    local app
    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak_installed "$app"; then
            record SKIP "Flatpak $app (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Flatpak $app (dry-run)"; continue
        fi
        confirm "Instalar Flatpak $app?" || { record SKIP "Flatpak $app (recusado)"; continue; }
        spinner_start "Instalando Flatpak $app..."
        run_cmd "Flatpak $app" "$LOG_DIR/flatpak_${app}.log" \
            flatpak install --user --noninteractive -y flathub "$app"
    done
}

# --- Ferramentas de desenvolvimento ----------------------------------------

setup_shell_env() {
    title "Variáveis de ambiente do shell"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Variáveis de ambiente em $ENV_FILE (dry-run)"; return
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<EOF
# Variáveis de ambiente das ferramentas instaladas.
# Gerado por instalar-fedora.sh — edite com cuidado.

# Binários do usuário (inclui o comando dotnet-install)
export PATH="\$HOME/.local/bin:\$PATH"

# opencode
export PATH="\$HOME/.opencode/bin:\$PATH"

# nvm (Node Version Manager)
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \\. "\$NVM_DIR/bash_completion"

# .NET SDK
export DOTNET_ROOT="\$HOME/.dotnet"
export DOTNET_INSTALL_DIR="\$HOME/.dotnet"
export PATH="\$PATH:\$DOTNET_ROOT:\$DOTNET_ROOT/tools"
EOF
    record OK "Arquivo de ambiente criado: $ENV_FILE"

    local marker="# --- instalar-fedora environment ---"
    local load_line="[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\""
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [ -e "$rc" ] || continue
        if ! grep -qF "$marker" "$rc"; then
            {
                printf '\n%s\n%s\n' "$marker" "$load_line"
            } >> "$rc"
            record OK "Carregamento adicionado em $rc"
        else
            record SKIP "Carregamento já presente em $rc"
        fi
    done

    # shellcheck disable=SC1090
    . "$ENV_FILE" 2>/dev/null || true
}

install_opencode() {
    title "Instalando opencode"
    if [ -x "$HOME/.opencode/bin/opencode" ]; then
        record SKIP "opencode (já instalado)"
    else
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "opencode (dry-run)"
        else
            confirm "Instalar o opencode?" || { record SKIP "opencode (recusado)"; }
            run_cmd "opencode" "$LOG_DIR/opencode.log" \
                bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'
        fi
    fi
}

install_nvm() {
    title "Instalando nvm (Node Version Manager)"
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        record SKIP "nvm (já instalado)"
    else
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "nvm (dry-run)"
        else
            confirm "Instalar o nvm?" || { record SKIP "nvm (recusado)"; }
            run_cmd "nvm" "$LOG_DIR/nvm.log" bash -c \
                "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
        fi
    fi

    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
    fi

    if [ -n "${NVM_NODE_VERSION:-}" ] && command -v nvm >/dev/null 2>&1; then
        local node_arg="$NVM_NODE_VERSION"
        case "$node_arg" in
            lts|lts/*|node) node_arg="--lts" ;;
        esac
        local node_label="${NVM_NODE_VERSION}"
        if [ "$node_arg" = "--lts" ]; then
            node_label="lts"
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Node ${node_label} via nvm (dry-run)"
        elif nvm ls "$node_label" >/dev/null 2>&1 && [ "$node_arg" != "--lts" ]; then
            record SKIP "Node ${node_label} (já instalado via nvm)"
        else
            spinner_start "Instalando Node ${node_label}..."
            run_cmd "Node ${node_label} (nvm install)" "$LOG_DIR/nvm_node.log" \
                nvm install "$node_arg"
        fi
    fi
}

install_dotnet() {
    title "Instalando .NET SDK (${DOTNET_CHANNELS[*]})"
    [ "${#DOTNET_CHANNELS[@]}" -eq 0 ] && { record SKIP ".NET (lista vazia)"; return; }
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP ".NET ${DOTNET_CHANNELS[*]} (dry-run)"; return
    fi
    have curl || { record FAIL ".NET (curl ausente)"; return; }

    local installer="$CACHE_HOME/dotnet-install.sh"
    if [ ! -s "$installer" ]; then
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer" \
            >>"$LOG_DIR/dotnet.log" 2>&1 \
            || { record FAIL ".NET (falha ao baixar dotnet-install.sh)"; return; }
        chmod +x "$installer"
    fi
    if [ ! -x "$HOME/.local/bin/dotnet-install" ]; then
        mkdir -p "$HOME/.local/bin"
        install -m 0755 "$installer" "$HOME/.local/bin/dotnet-install"
        record OK "Comando dotnet-install instalado em ~/.local/bin"
    fi

    local channel
    for channel in "${DOTNET_CHANNELS[@]}"; do
        if [ -x "$HOME/.dotnet/dotnet" ] && "$HOME/.dotnet/dotnet" --list-sdks 2>/dev/null | grep -q "^${channel}\."; then
            record SKIP ".NET SDK ${channel} (já instalado)"
            continue
        fi
        confirm "Instalar .NET SDK canal ${channel}?" || { record SKIP ".NET ${channel} (recusado)"; continue; }
        spinner_start "Instalando .NET SDK ${channel}..."
        run_cmd ".NET SDK ${channel}" "$LOG_DIR/dotnet_${channel}.log" \
            "$installer" --channel "$channel" --install-dir "$HOME/.dotnet"
    done
    info "Para outras versões, use: dotnet-install --channel <versao>"
    info "Liste o instalado com: dotnet --list-sdks"
}

cleanup() {
    title "Limpeza (autoremove/clean)"
    confirm "Executar autoremove e clean?" || { record SKIP "Limpeza (recusada)"; return; }
    run_cmd "dnf autoremove" "$LOG_DIR/autoremove.log" \
        "${DNF_ENV[@]}" "${SUDO[@]}" dnf autoremove "${DNF_OPTS[@]}"
    run_cmd "dnf clean all" "$LOG_DIR/clean.log" "${SUDO[@]}" dnf clean all
}

# ===========================================================================
# RESUMO
# ===========================================================================

print_summary() {
    spinner_stop
    title "Resumo"
    printf '  %sOK:%s %d   %sSKIP:%s %d   %sFALHA:%s %d\n' \
        "$C_OK" "$C_RESET" "$OK_COUNT" \
        "$C_WARN" "$C_RESET" "$SKIP_COUNT" \
        "$C_ERR" "$C_RESET" "$FAIL_COUNT"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        err "Itens com falha:"
        local item
        for item in "${FAILED_ITEMS[@]}"; do printf '  - %s\n' "$item" >&2; done
    fi
    info "Resumo: $SUMMARY"
    info "Logs:   $LOG_DIR"
    [ "$FAIL_COUNT" -gt 0 ] && return 1 || return 0
}

usage() {
    sed -n '2,/^set -uo pipefail/p' "$SCRIPT_PATH" | sed '$d' | sed 's/^# \{0,1\}//'
}

# ===========================================================================
# MAIN
# ===========================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)         ASSUME_YES=1 ;;
            -n|--dry-run)     DRY_RUN=1; ASSUME_YES=1 ;;
            --no-upgrade)     DO_UPGRADE=0 ;;
            --no-self-update) SELF_UPDATE="no" ;;
            --only)           ONLY="${2:-}"; shift ;;
            --no-color)       NO_COLOR=1 ;;
            -v|--verbose)     VERBOSE=1 ;;
            -h|--help)        usage; exit 0 ;;
            *) err "Opção desconhecida: $1"; usage; exit 2 ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    if [ "$NO_COLOR" -eq 1 ]; then
        C_RESET=""; C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_BOLD=""
    fi

    mkdir -p "$LOG_DIR" "$RPM_DIR"
    printf 'Resumo da instalação - %s\n\n' "$(date)" > "$SUMMARY"

    printf '%s\n' "${C_BOLD}Instalador Fedora Workstation${C_RESET}"
    [ "$DRY_RUN" -eq 1 ] && warn "MODO DRY-RUN: nada será alterado."

    setup_sudo
    ensure_askpass
    setup_sudo

    if [ "$DRY_RUN" -eq 0 ]; then
        prime_sudo || { err "Sem autorização; encerrando."; print_summary; exit 1; }
    fi

    preflight
    [ "$SELF_UPDATE" = "yes" ] && self_update

    case "$ONLY" in
        dnf)      dnf_refresh; dnf_upgrade; dnf_install ;;
        repos)    add_third_party_repos ;;
        rpm)      install_chrome; install_direct_rpms ;;
        flatpak)  flatpak_setup; flatpak_install ;;
        dev)      setup_shell_env; install_opencode; install_nvm; install_dotnet ;;
        cleanup)  cleanup ;;
        "")
            dnf_refresh
            dnf_upgrade
            dnf_install
            add_third_party_repos
            install_chrome
            install_direct_rpms
            flatpak_setup
            flatpak_install
            setup_shell_env
            install_opencode
            install_nvm
            install_dotnet
            cleanup
            ;;
        *) err "Grupo inválido para --only: $ONLY"; exit 2 ;;
    esac

    print_summary
}

trap 'spinner_stop' EXIT INT TERM

main "$@"