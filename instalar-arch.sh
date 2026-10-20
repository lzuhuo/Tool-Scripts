#!/usr/bin/env bash
#
# instalar-arch.sh
# ---------------------------------------------------------------------------
# Provisiona uma instalação limpa do Arch Linux (x86_64).
#
# Estratégia de instalação (preferência decrescente):
#   1. Pacotes dos repositórios oficiais (core/extra) — atualizam via pacman.
#   2. AUR via yay — pacotes que não estão nos repositórios oficiais.
#      Vantagem: atualizam junto com "yay -Syu".
#   3. Flatpak/Flathub — apenas para o que não tem pacote nativo confiável.
#
# Recursos:
#   - Autorização gráfica (janela de senha) quando não há terminal.
#   - Logs e cache em ~/.local, fora do repositório.
#   - Tratamento de erro real, contagem de falhas e resumo final.
#   - Idempotente: pode ser reexecutado sem quebrar.
#   - Auto-atualização opcional a partir de URL do repositório Git.
#
# Uso:
#   ./instalar-arch.sh [opções]
#
# Opções:
#   -y, --yes         Não perguntar nada (modo não interativo).
#   -n, --dry-run     Mostra o que faria, sem alterar o sistema.
#   --no-upgrade      Pula o "pacman -Syu" (só instala o que falta).
#   --no-self-update  Não tenta atualizar o script pelo Git.
#   --only <grupo>    Executa só um grupo:
#                     pacman|yay|flatpak|extensions|dev|cleanup
#   -h, --help        Mostra esta ajuda.
#
# Requisitos: Arch Linux (x86_64), internet, usuário com sudo.
# ---------------------------------------------------------------------------

set -uo pipefail

# ===========================================================================
# CONFIGURAÇÃO
# ===========================================================================

# --- Pacotes dos repositórios oficiais do Arch (pacman) --------------------
PACMAN_PACKAGES=(
    git
    curl
    wget
    flameshot
    gnome-tweaks
    gnome-browser-connector
    firefox
    flatpak
    keepassxc
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    openvpn
    networkmanager-openvpn
    networkmanager
    ttf-liberation
    xcb-util-cursor
    inetutils
    # tilix está no AUR, não no oficial
)

# --- Pacotes do AUR (via yay) ----------------------------------------------
# Formato: "Nome|pacote_aura1 pacote_aura2 ..."
AUR_PACKAGES=(
    "Google Chrome|google-chrome"
    "Microsoft Edge|microsoft-edge-stable-bin"
    "Zoom|zoom"
    "Visual Studio Code|visual-studio-code-bin"
    "DBeaver CE|dbeaver-ce-bin"
    "Postman|postman-bin"
    "Ulauncher|ulauncher"
    "Free Download Manager|freedownloadmanager-bin"
    "Ferdium|ferdium-bin"
    "AnyDesk|anydesk-bin"
    "RealVNC Viewer|realvnc-vnc-viewer"
    "WinBox|winbox"
    "Extension Manager|extension-manager-git"
    "Tilix|tilix"
    "GNOME Extensions|gnome-shell-extension-blur-my-shell gnome-shell-extension-dash-to-dock gnome-shell-extension-compiz-alike-magic-lamp-effect-git gnome-shell-extension-compiz-windows-effect-git gnome-shell-extension-vitals-git"
)

# --- Aplicativos via Flatpak (Flathub) -------------------------------------
FLATPAK_APPS=()

# --- Ferramentas de desenvolvimento ----------------------------------------
NVM_VERSION="v0.40.8"
NVM_NODE_VERSION="lts"
DOTNET_CHANNELS=(10.0 8.0)
ENV_FILE="$HOME/.config/instalar-arch/env.sh"

# --- Auto-atualização ------------------------------------------------------
REPO_RAW_URL=""
SELF_UPDATE="yes"

# --- Caminhos --------------------------------------------------------------
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/instalar-arch"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/instalar-arch"
LOG_DIR="$DATA_HOME/logs"
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

# --- Flags -----------------------------------------------------------------
ASSUME_YES=0
DRY_RUN=0
DO_UPGRADE=1
ONLY=""
NO_COLOR=0
VERBOSE=0

SPINNER_PID=""
SPINNER_TEXT=""

# pacman options
PACMAN_OPTS=(--needed --noconfirm)
YAY_OPTS=(--needed --noconfirm)

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
        zenity --question --title="Instalação Arch" --width=420 --text="$question" 2>/dev/null
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

have() { command -v "$1" >/dev/null 2>&1; }
pacman_installed() { pacman -Q "$1" >/dev/null 2>&1; }
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
        record OK "Autorização concedida"
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

    # Verificação simplificada: se temos pacman, é Arch-based
    if have pacman; then
        record OK "Sistema: Arch Linux (pacman disponível)"
    else
        record FAIL "Não detectado Arch Linux (pacman não encontrado); abortando."
        exit 1
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            # Verifica se é Arch confirmando pacman e possivelmente /etc
            if [ "${ID:-}" = "arch" ]; then
                record OK "Sistema confirmado: Arch Linux (${VERSION_ID:-?})"
            else
                record SKIP "Sistema não é Arch confirmado (${ID:-?}); mas pacman disponível, continuando"
            fi
        fi
    else
        record SKIP "Verificação de SO (dry-run)"
    fi

    if have curl || have wget; then record OK "Ferramenta de download disponível"
    else record FAIL "Sem curl/wget para downloads"; fi

    if have pacman; then record OK "pacman disponível"
    else record FAIL "pacman não encontrado"; exit 1; fi

    if have yay; then record OK "yay disponível"
    elif [ "$DRY_RUN" -eq 0 ]; then
        record SKIP "yay não instalado (será instalado na etapa AUR)"
    else
        record SKIP "Verificação de yay (dry-run)"
    fi
}

# ===========================================================================
# ETAPAS
# ===========================================================================

pacman_refresh() {
    title "Atualizando banco de dados (pacman -Sy)"
    confirm "Executar 'pacman -Sy'?" || { record SKIP "pacman -Sy (recusado)"; return; }
    run_cmd "pacman -Sy" "$LOG_DIR/pacman_sy.log" "${SUDO[@]}" pacman -Sy "${PACMAN_OPTS[@]}"
}

pacman_upgrade() {
    title "Atualização do sistema (pacman -Syu)"
    [ "$DO_UPGRADE" -eq 1 ] || { record SKIP "pacman -Syu desativado"; return; }
    confirm "Executar 'pacman -Syu'? Isso pode demorar." || { record SKIP "pacman -Syu (recusado)"; return; }
    run_cmd "pacman -Syu" "$LOG_DIR/pacman_syu.log" "${SUDO[@]}" pacman -Syu "${PACMAN_OPTS[@]}"
}

pacman_install() {
    title "Pacotes oficiais (pacman)"
    local missing=() p
    for p in "${PACMAN_PACKAGES[@]}"; do
        pacman_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        record SKIP "Pacotes oficiais (todos já instalados)"; return
    fi
    info "Faltando: ${#missing[@]} pacote(s)"
    confirm "Instalar ${#missing[@]} pacote(s) via pacman?" || { record SKIP "Pacotes oficiais (recusado)"; return; }

    for p in "${missing[@]}"; do
        run_cmd "$p" "$LOG_DIR/pacman_install.log" \
            "${SUDO[@]}" pacman -S "${PACMAN_OPTS[@]}" "$p"
    done
}

aur_refresh() {
    have yay || { record SKIP "yay não instalado; pulando AUR"; return; }
    run_cmd "yay -Sy" "$LOG_DIR/yay_sy.log" "${SUDO[@]}" yay -Sy "${YAY_OPTS[@]}"
}

aur_install() {
    title "Pacotes AUR (yay)"
    aur_refresh
    [ "${#AUR_PACKAGES[@]}" -eq 0 ] && { record SKIP "AUR (lista vazia)"; return; }

    local entry name pkgs first_pkg
    for entry in "${AUR_PACKAGES[@]}"; do
        IFS='|' read -r name pkgs <<< "$entry"
        first_pkg="${pkgs%% *}"
        if aur_installed "$first_pkg"; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$name (dry-run): $pkgs"; continue
        fi
        confirm "Instalar $name via AUR?" || { record SKIP "$name (recusado)"; continue; }
        # shellcheck disable=SC2086
        run_cmd "AUR $name" "$LOG_DIR/aur_${name// /_}.log" \
            yay -S "${YAY_OPTS[@]}" $pkgs
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
    have flatpak || { record FAIL "Flatpak ausente"; return; }

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

# --- Extensões GNOME -------------------------------------------------------
install_gnome_extensions() {
    title "Extensões GNOME (via AUR)"
    have yay || { record FAIL "yay não disponível; pulando extensões"; return; }

    # Extensões via AUR (nomes corretos)
    local extensions=(
        "gnome-shell-extension-blur-my-shell"
        "gnome-shell-extension-dash-to-dock"
        "gnome-shell-extension-compiz-alike-magic-lamp-effect-git"
        "gnome-shell-extension-compiz-windows-effect-git"
        "gnome-shell-extension-vitals-git"
    )

    local uuid
    for uuid in "${extensions[@]}"; do
        if aur_installed "$uuid"; then
            record SKIP "Extensão AUR $uuid (já instalada)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Extensão AUR $uuid (dry-run)"; continue
        fi
        confirm "Instalar extensão GNOME $uuid via AUR?" || { record SKIP "$uuid (recusada)"; continue; }
        spinner_start "Instalando extensão $uuid..."
        run_cmd "Extensão AUR $uuid" "$LOG_DIR/ext_${uuid}.log" \
            yay -S "${YAY_OPTS[@]}" "$uuid"
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
# Gerado por instalar-arch.sh — edite com cuidado.

# Binários do usuário
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

    local marker="# --- instalar-arch environment ---"
    local load_line="[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\""
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [ -e "$rc" ] || continue
        if ! grep -qF "$marker" "$rc"; then
            { printf '\n%s\n%s\n' "$marker" "$load_line"; } >> "$rc"
            record OK "Carregamento adicionado em $rc"
        else
            record SKIP "Carregamento já presente em $rc"
        fi
    done

    # shellcheck source=/dev/null
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
        . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
    fi

    if [ -n "${NVM_NODE_VERSION:-}" ] && command -v nvm >/dev/null 2>&1; then
        local node_arg="$NVM_NODE_VERSION"
        case "$node_arg" in lts|lts/*|node) node_arg="--lts" ;;
        esac
        local node_label="${NVM_NODE_VERSION}"
        if [ "$node_arg" = "--lts" ]; then node_label="lts"; fi
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
    info "Para outras versões: dotnet-install --channel <versao>"
    info "Liste instalado: dotnet --list-sdks"
}

cleanup() {
    title "Limpeza (cache do pacman/yay)"
    confirm "Limpar cache do pacman e yay?" || { record SKIP "Limpeza (recusada)"; return; }
    run_cmd "pacman clean" "$LOG_DIR/pacman_clean.log" \
        "${SUDO[@]}" pacman -Sc "${PACMAN_OPTS[@]}"
    if have yay; then
        run_cmd "yay clean" "$LOG_DIR/yay_clean.log" \
            yay -Sc "${YAY_OPTS[@]}"
    fi
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
        C_DIM=""; C_BAR=""
    fi

    mkdir -p "$LOG_DIR"
    printf 'Resumo da instalação - %s\n\n' "$(date)" > "$SUMMARY"

    printf '%s\n' "${C_BOLD}Instalador Arch Linux${C_RESET}"
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
        pacman)     pacman_refresh; pacman_upgrade; pacman_install ;;
        yay)        aur_install ;;
        flatpak)    flatpak_setup; flatpak_install ;;
        extensions) install_gnome_extensions ;;
        dev)        setup_shell_env; install_opencode; install_nvm; install_dotnet ;;
        cleanup)    cleanup ;;
        "")
            pacman_refresh
            pacman_upgrade
            pacman_install
            aur_install
            flatpak_setup
            flatpak_install
            install_gnome_extensions
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