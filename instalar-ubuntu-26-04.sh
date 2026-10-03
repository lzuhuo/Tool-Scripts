#!/usr/bin/env bash
#
# instalar-ubuntu-26-04.sh
# ---------------------------------------------------------------------------
# Provisiona uma instalação limpa do Ubuntu 26.04.x LTS ("resolute").
#
# Estratégia de instalação (preferência decrescente):
#   1. Pacotes dos repositórios oficiais do Ubuntu (universe/main).
#   2. PPAs do Launchpad e repositórios APT oficiais de terceiros
#      (Ulauncher, Chrome, VS Code, Edge, DBeaver, AnyDesk) e pacotes
#      .deb avulsos (Zoom, FDM, Ferdium, WiFiman, Zoiper).
#      Vantagem: atualizam junto com "apt upgrade".
#   3. Flatpak/Flathub apenas para o que não tem pacote APT confiável
#      (Postman, WinBox).
#
# Recursos:
#   - Autorização gráfica (janela de senha) quando não há terminal.
#   - Logs e cache de .deb em ~/.local, fora do repositório.
#   - Tratamento de erro real, contagem de falhas e resumo final.
#   - Idempotente: pode ser reexecutado sem quebrar.
#   - Auto-atualização opcional a partir de URL do repositório Git.
#
# Uso:
#   ./instalar-ubuntu-26-04.sh [opções]
#
# Opções:
#   -y, --yes         Não perguntar nada (modo não interativo).
#   -n, --dry-run     Mostra o que faria, sem alterar o sistema.
#   --no-upgrade      Pula o "apt upgrade" (só instala o que falta).
#   --no-self-update  Não tenta atualizar o script pelo Git.
#   --only <grupo>    Executa só um grupo:
#                     apt|repos|ppa|deb|flatpak|extensions|dev|manual|cleanup
#   -h, --help        Mostra esta ajuda.
#
# Requisitos: Ubuntu 26.04, internet, usuário com sudo.
# ---------------------------------------------------------------------------

set -uo pipefail

# ===========================================================================
# CONFIGURAÇÃO
# ===========================================================================

# --- Pacotes dos repositórios oficiais do Ubuntu -------------------------
APT_PACKAGES=(
    tilix              # terminal emulado
    flameshot          # captura de tela
    git
    curl
    wget
    ca-certificates
    gnupg              # necessária para importar chaves de repositórios
    zenity             # janelas de senha/confirmação
    gnome-tweaks
    gnome-browser-connector
    flatpak
    keepassxc          # gerenciador de senhas
    remmina            # cliente VNC/RDP/SSH (substitui o RealVNC)
    remmina-plugin-rdp
    remmina-plugin-vnc
    gnome-shell-extension-manager  # substitui o app Flatpak Extension Manager
    unzip              # usado para instalar extensões GNOME
    software-properties-common     # fornece add-apt-repository (PPAs)
    openvpn            # VPN
    network-manager-openvpn
    network-manager-openvpn-gnome
    network-manager-applet
    inetutils-telnet   # cliente telnet
    inetutils-traceroute
    # Obs.: "inetutils-ping" conflita com o iputils-ping padrão do Ubuntu,
    # por isso o ping nativo foi mantido.
)

# --- Repositórios APT oficiais de terceiros ------------------------------
# Formato: "Nome|URL_da_chave|URL_do_repo|suite|componentes|pacotes"
# "pacotes" pode conter vários separados por espaço.
THIRD_PARTY_REPOS=(
    "Google Chrome|https://dl.google.com/linux/linux_signing_key.pub|https://dl.google.com/linux/chrome/deb/|stable|main|google-chrome-stable"
    "Visual Studio Code|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/repos/code|stable|main|code"
    "Microsoft Edge|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/repos/edge|stable|main|microsoft-edge-stable"
    "DBeaver CE|https://dbeaver.io/debs/dbeaver.gpg.key|https://dbeaver.io/debs/dbeaver-ce/|/||dbeaver-ce"
    "AnyDesk|https://keys.anydesk.com/repos/DEB-GPG-KEY|http://deb.anydesk.com/|all|main|anydesk"
)

# --- PPAs (repositórios pessoais do Launchpad) ---------------------------
# Formato: "Nome|ppa:usuario/ppa|pacotes"
# Vantagem: o aplicativo passa a atualizar junto com o apt.
PPAS=(
    "Ulauncher|ppa:agornostal/ulauncher|ulauncher"
)

# --- Pacotes .deb avulsos -------------------------------------------------
# Formato: "Nome|URL|arquivo_local|pacote_dpkg"
# A URL pode ser "gh:owner/repo[:sufixo]" para resolver o .deb mais recente
# de um release do GitHub automaticamente.
DIRECT_DEBS=(
    "Zoom|https://zoom.us/client/latest/zoom_amd64.deb|zoom_amd64.deb|zoom"
    "Free Download Manager|https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb|freedownloadmanager.deb|freedownloadmanager"
    "Ferdium|gh:ferdium/ferdium-app|ferdium_amd64.deb|ferdium"
    "WiFiman Desktop|https://desktop.wifiman.com/wifiman-desktop-1.3.0-amd64.deb|wifiman-desktop.deb|wifiman-desktop"
)

# --- Download manual (modal de navegador) --------------------------------
# Aplicativos que exigem interação (login/anti-bot). No final do script é
# aberta uma janela do navegador na página exata; quando o download é
# detectado em ~/Downloads, a janela fecha e a instalação continua.
# Formato: "Nome|URL_da_pagina|padrao_do_arquivo|pacote_dpkg"
MANUAL_DOWNLOADS=(
    "Zoiper 5|https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb|Zoiper*.deb|zoiper5"
)

# --- Extensões GNOME (extensions.gnome.org) ------------------------------
# Instaladas em ~/.local/share/gnome-shell/extensions e (quando possível)
# habilitadas. Extensões sem suporte à versão do GNOME atual são ignoradas.
GNOME_EXTENSIONS=(
    blur-my-shell@aunetx
    dash-to-dock@micxgx.gmail.com
    Vitals@CoreCoding.com
    show-desktop-button@amivaleo
    compiz-alike-magic-lamp-effect@hermes83.github.com
    compiz-windows-effect@hermes83.github.com
)

# --- Ferramentas de desenvolvimento --------------------------------------
# nvm
NVM_VERSION="v0.40.8"          # versão do nvm a instalar
NVM_NODE_VERSION="lts"         # versão do Node a instalar após o nvm ("" pula)

# .NET SDK — instale os canais que quiser (side-by-side). Ex.: (8.0 9.0 10.0)
DOTNET_CHANNELS=(10.0 8.0)

# Arquivo único com as variáveis de ambiente, carregado pelo ~/.bashrc.
ENV_FILE="$HOME/.config/instalar-ubuntu/env.sh"

# --- Aplicativos via Flatpak (Flathub) -----------------------------------
# Apenas o que não tem pacote APT/deb confiável.
FLATPAK_APPS=(
    com.getpostman.Postman
    com.mikrotik.WinBox
)

# --- Auto-atualização do script pelo repositório Git ---------------------
# Deixe vazio para desativar. Exemplo:
#   REPO_RAW_URL="https://raw.githubusercontent.com/usuario/repo/main/instalar-ubuntu-26-04.sh"
REPO_RAW_URL=""
SELF_UPDATE="yes"

# --- Caminhos -------------------------------------------------------------
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/instalar-ubuntu"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/instalar-ubuntu"
LOG_DIR="$DATA_HOME/logs"
DEB_DIR="$CACHE_HOME/deb"
SUMMARY="$LOG_DIR/summary.log"

# --- Cores ----------------------------------------------------------------
if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_ERR=$'\033[31m'
    C_WARN=$'\033[33m'; C_INFO=$'\033[36m'; C_BOLD=$'\033[1m'
else
    C_RESET=""; C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_BOLD=""
fi

# --- Contadores -----------------------------------------------------------
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILED_ITEMS=()

# --- Flags ----------------------------------------------------------------
ASSUME_YES=0
DRY_RUN=0
DO_UPGRADE=1
ONLY=""

# ===========================================================================
# FUNÇÕES BÁSICAS
# ===========================================================================

info()  { printf '%s\n' "${C_INFO}$*${C_RESET}"; }
warn()  { printf '%s\n' "${C_WARN}$*${C_RESET}"; }
err()   { printf '%s\n' "${C_ERR}$*${C_RESET}" >&2; }
title() { printf '\n%s\n' "${C_BOLD}==> $*${C_RESET}"; }

record() {
    local status="$1" label="$2"
    case "$status" in
        OK)   OK_COUNT=$((OK_COUNT + 1));     printf '%s\n' "${C_OK}[OK]${C_RESET}    $label" ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)); printf '%s\n' "${C_WARN}[SKIP]${C_RESET}  $label" ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED_ITEMS+=("$label")
              printf '%s\n' "${C_ERR}[FALHA]${C_RESET} $label" ;;
    esac
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$label" >> "$SUMMARY"
}

confirm() {
    local question="$1"
    [ "$ASSUME_YES" -eq 1 ] && return 0
    if [ -t 0 ]; then
        local reply
        read -r -p "${C_WARN}$question [s/N] ${C_RESET}" reply
        case "$reply" in [sSyY]*) return 0 ;; *) return 1 ;; esac
    elif command -v zenity >/dev/null 2>&1; then
        zenity --question --title="Instalação Ubuntu" --width=420 --text="$question" 2>/dev/null
    else
        return 0
    fi
}

run_cmd() {
    # run_cmd <rótulo> <log> <comando...>
    local label="$1" logfile="$2"; shift 2
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "$label (dry-run): $*"
        return 0
    fi
    if "$@" >>"$logfile" 2>&1; then
        record OK "$label"; return 0
    fi
    record FAIL "$label (veja $logfile)"; return 1
}

have()        { command -v "$1" >/dev/null 2>&1; }
pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

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

# Pede a senha uma única vez e mantém o ticket em cache durante a execução.
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

    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "${ID:-}" = "ubuntu" ]; then
            record OK "Sistema: Ubuntu ${VERSION_ID:-?} (${VERSION_CODENAME:-?})"
        else
            record SKIP "Sistema não é Ubuntu (${ID:-?}); seguindo mesmo assim"
        fi
    fi

    if have curl || have wget; then record OK "Ferramenta de download disponível"
    else record FAIL "Sem curl/wget para downloads"; fi

    if have apt-get; then record OK "apt-get disponível"
    else record FAIL "apt-get não encontrado"; exit 1; fi
}

# ===========================================================================
# ETAPAS
# ===========================================================================

apt_refresh() {
    title "Atualizando índices de pacotes (apt update)"
    confirm "Executar 'apt update'?" || { record SKIP "apt update (recusado)"; return; }
    run_cmd "apt update" "$LOG_DIR/apt_update.log" "${SUDO[@]}" apt-get update
}

apt_upgrade() {
    [ "$DO_UPGRADE" -eq 1 ] || { record SKIP "apt upgrade desativado"; return; }
    title "Atualizando pacotes instalados (apt upgrade)"
    confirm "Executar 'apt upgrade'? Isso pode demorar." || { record SKIP "apt upgrade (recusado)"; return; }
    run_cmd "apt upgrade" "$LOG_DIR/apt_upgrade.log" \
        env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get upgrade -y
}

apt_install() {
    title "Instalando pacotes oficiais do Ubuntu"
    local missing=() p
    for p in "${APT_PACKAGES[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        record SKIP "Pacotes oficiais (todos já instalados)"; return
    fi
    info "Faltando: ${missing[*]}"
    confirm "Instalar ${#missing[@]} pacote(s) via apt?" || { record SKIP "Pacotes oficiais (recusado)"; return; }
    run_cmd "Pacotes oficiais (apt install)" "$LOG_DIR/apt_install.log" \
        env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y --no-install-recommends "${missing[@]}"
}

# --- Repositórios APT de terceiros ---------------------------------------
add_third_party_repos() {
    title "Configurando repositórios APT de terceiros"
    [ "${#THIRD_PARTY_REPOS[@]}" -eq 0 ] && { record SKIP "Sem repositórios de terceiros"; return; }

    local tmp; tmp="$(mktemp -d)"
    local entry name key_url repo_url suite components pkgs base keyring script
    script="$tmp/setup.sh"
    : > "$script"

    for entry in "${THIRD_PARTY_REPOS[@]}"; do
        IFS='|' read -r name key_url repo_url suite components pkgs <<< "$entry"
        base="$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-')"
        keyring="/usr/share/keyrings/${base}.gpg"

        # Baixa a chave (sem root) e converte para formato binário.
        printf 'echo "  - %s"\n' "$name" >> "$script"
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Repositório $name (dry-run)"
            continue
        fi
        if have curl; then
            curl -fsSL "$key_url" -o "$tmp/${base}.key" 2>>"$LOG_DIR/repos.log" \
                || { record FAIL "Chave de $name (veja $LOG_DIR/repos.log)"; continue; }
        else
            wget -qO "$tmp/${base}.key" "$key_url" 2>>"$LOG_DIR/repos.log" \
                || { record FAIL "Chave de $name (veja $LOG_DIR/repos.log)"; continue; }
        fi

        # Escreve, no script root, a importação da chave e o .list.
        {
            echo "gpg --dearmor --yes -o '$keyring' '$tmp/${base}.key'"
            echo "chmod 0644 '$keyring'"
            if [ -n "$components" ]; then
                echo "printf '%s\n' 'deb [signed-by=$keyring] $repo_url $suite $components' > '/etc/apt/sources.list.d/${base}.list'"
            else
                echo "printf '%s\n' 'deb [signed-by=$keyring] $repo_url $suite' > '/etc/apt/sources.list.d/${base}.list'"
            fi
        } >> "$script"
        record OK "Repositório $name configurado"
    done

    if [ "$DRY_RUN" -eq 0 ]; then
        chmod +x "$script"
        if "${SUDO[@]}" /bin/bash "$script" >>"$LOG_DIR/repos.log" 2>&1; then
            record OK "Repositórios de terceiros aplicados"
            run_cmd "apt update (após repositórios)" "$LOG_DIR/apt_update.log" "${SUDO[@]}" apt-get update
        else
            record FAIL "Aplicação dos repositórios (veja $LOG_DIR/repos.log)"
        fi
    fi
    rm -rf "$tmp"

    # Instala os pacotes de cada repositório.
    title "Instalando aplicativos dos repositórios de terceiros"
    for entry in "${THIRD_PARTY_REPOS[@]}"; do
        IFS='|' read -r name key_url repo_url suite components pkgs <<< "$entry"
        local p installed=0
        for p in $pkgs; do pkg_installed "$p" && installed=1; done
        if [ "$installed" -eq 1 ]; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Instalação $name (dry-run): $pkgs"; continue
        fi
        confirm "Instalar $name?" || { record SKIP "$name (recusado)"; continue; }
        # shellcheck disable=SC2086
        run_cmd "Instalação $name" "$LOG_DIR/apt_third_${name// /_}.log" \
            env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y $pkgs
    done
}

# --- PPAs ----------------------------------------------------------------
add_ppas() {
    title "Adicionando PPAs (Launchpad)"
    [ "${#PPAS[@]}" -eq 0 ] && { record SKIP "Sem PPAs configuradas"; return; }
    have add-apt-repository || { record FAIL "add-apt-repository ausente (instale software-properties-common)"; return; }

    local entry name ppa pkgs
    for entry in "${PPAS[@]}"; do
        IFS='|' read -r name ppa pkgs <<< "$entry"
        local p installed=0
        for p in $pkgs; do pkg_installed "$p" && installed=1; done
        if [ "$installed" -eq 1 ]; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "PPA $name (dry-run): $ppa"; continue
        fi
        confirm "Adicionar e instalar do $name ($ppa)?" || { record SKIP "$name (recusado)"; continue; }
        if run_cmd "PPA $name" "$LOG_DIR/ppa_${name// /_}.log" \
            "${SUDO[@]}" add-apt-repository -y "$ppa"; then
            run_cmd "apt update (após PPA $name)" "$LOG_DIR/apt_update.log" "${SUDO[@]}" apt-get update
            # shellcheck disable=SC2086
            run_cmd "Instalação $name (via PPA)" "$LOG_DIR/ppa_install_${name// /_}.log" \
                env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y $pkgs
        fi
    done
}

# --- Pacotes .deb avulsos -------------------------------------------------
github_latest_deb() {
    # github_latest_deb <owner/repo> [sufixo]
    local repo="$1" suffix="${2:-amd64.deb}"
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -oE '"browser_download_url": "[^"]+"' \
        | sed -E 's/.*"(https:[^"]+)"/\1/' \
        | grep -E "${suffix}$" | head -n1
}

# Abre um modal de navegador na página de download e aguarda o arquivo
# aparecer em ~/Downloads. Detectado o arquivo válido, fecha a janela.
# Define a global MANUAL_FILE com o caminho baixado (vazio em caso de falha).
manual_download() {
    # manual_download <nome> <url> <padrao>
    local name="$1" url="$2" pattern="$3"
    MANUAL_FILE=""
    local dl_dir; dl_dir="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
    mkdir -p "$dl_dir"

    # Detecta navegador disponível.
    local browser="" profile
    local b
    for b in google-chrome-stable google-chrome chromium firefox; do
        if have "$b"; then browser="$b"; break; fi
    done
    if [ -z "$browser" ]; then
        record FAIL "$name (nenhum navegador encontrado para o modal)"
        return 1
    fi
    if ! have wmctrl; then
        info "Instalando wmctrl (necessário para fechar o modal)..."
        "${SUDO[@]}" apt-get install -y wmctrl >>"$LOG_DIR/manual.log" 2>&1 || true
    fi

    info "Abrindo o navegador na página de download de $name."
    info "Baixe o arquivo '${pattern}' — o script detecta e continua sozinho."

    profile="$(mktemp -d)"
    local title="Download $name"
    # Abre em janela dedicada (perfil isolado) para poder fechar depois.
    "$browser" --user-data-dir="$profile" --new-window --app="$url" \
        >>"$LOG_DIR/manual.log" 2>&1 &
    local bpid=$!

    # Aguarda o arquivo aparecer (até 15 min), ignorando parciais.
    local found="" waited=0
    while [ "$waited" -lt 900 ]; do
        # shellcheck disable=SC2086
        found="$(find "$dl_dir" -maxdepth 1 -type f -name "$pattern" \
                    ! -name '*.crdownload' ! -name '*.part' \
                    -mmin -30 2>/dev/null | head -n1)"
        if [ -n "$found" ] && [ -s "$found" ]; then
            # Aguarda o tamanho estabilizar (download em andamento).
            local s1 s2
            s1="$(stat -c%s "$found" 2>/dev/null || echo 0)"
            sleep 2
            s2="$(stat -c%s "$found" 2>/dev/null || echo 0)"
            if [ "$s1" = "$s2" ] && [ "$s1" -gt 0 ]; then
                break
            fi
        fi
        sleep 2; waited=$((waited + 2))
    done

    # Fecha o modal.
    if have wmctrl; then
        wmctrl -c "$title" 2>/dev/null || true
    fi
    kill "$bpid" 2>/dev/null || true
    sleep 1
    rm -rf "$profile"

    if [ -n "$found" ] && [ -s "$found" ]; then
        MANUAL_FILE="$found"
        return 0
    fi
    record FAIL "$name (download não detectado em $dl_dir)"
    return 1
}

install_manual_downloads() {
    [ "${#MANUAL_DOWNLOADS[@]}" -eq 0 ] && return
    title "Downloads manuais (janela do navegador)"
    local entry name url pattern pkg
    for entry in "${MANUAL_DOWNLOADS[@]}"; do
        IFS='|' read -r name url pattern pkg <<< "$entry"
        if pkg_installed "$pkg"; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$name (dry-run): modal em $url"; continue
        fi
        confirm "Abrir o navegador para baixar $name agora?" \
            || { record SKIP "$name (recusado)"; continue; }

        manual_download "$name" "$url" "$pattern" || continue
        [ -n "$MANUAL_FILE" ] || { record FAIL "$name (arquivo não encontrado)"; continue; }

        if run_cmd "Instalação $name" "$LOG_DIR/deb_install.log" \
            env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y "$MANUAL_FILE"; then
            info "Arquivo baixado mantido em: $MANUAL_FILE"
        fi
    done
}

install_direct_debs() {
    title "Instalando pacotes .deb avulsos"
    [ "${#DIRECT_DEBS[@]}" -eq 0 ] && { record SKIP "Pacotes .deb (lista vazia)"; return; }

    local entry name url file pkg dest real_url
    for entry in "${DIRECT_DEBS[@]}"; do
        IFS='|' read -r name url file pkg <<< "$entry"
        dest="$DEB_DIR/$file"

        if pkg_installed "$pkg"; then
            record SKIP "$name (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Instalação $name (dry-run)"; continue
        fi
        confirm "Baixar e instalar $name?" || { record SKIP "$name (recusado)"; continue; }

        real_url="$url"
        if [[ "$url" == gh:* ]]; then
            local ghrepo="${url#gh:}"
            local ghsuffix="amd64.deb"
            if [[ "$ghrepo" == *:* ]]; then
                ghsuffix="${ghrepo##*:}"
                ghrepo="${ghrepo%%:*}"
            fi
            real_url="$(github_latest_deb "$ghrepo" "$ghsuffix")"
            if [ -z "$real_url" ]; then
                record FAIL "$name (não foi possível resolver o release no GitHub)"; continue
            fi
        fi

        # Rebaixa se o arquivo local estiver vazio/corrompido.
        if [ -n "$real_url" ] && [ ! -s "$dest" ]; then
            if have curl; then
                curl -fL --retry 3 -o "$dest" "$real_url" >>"$LOG_DIR/deb_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/deb_download.log)"; continue; }
            else
                wget -qO "$dest" "$real_url" >>"$LOG_DIR/deb_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/deb_download.log)"; continue; }
            fi
        fi

        if run_cmd "Instalação $name" "$LOG_DIR/deb_install.log" \
            env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y "$dest"; then
            :
        fi
    done

    run_cmd "Correção de dependências (apt -f)" "$LOG_DIR/deb_fix.log" \
        env DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get -f install -y
}

# --- Flatpak --------------------------------------------------------------
flatpak_setup() {
    title "Configurando Flatpak e Flathub"
    have flatpak || { record FAIL "Flatpak não instalado; pulando"; return 1; }
    confirm "Adicionar o repositório Flathub?" || { record SKIP "Flathub (recusado)"; return; }
    run_cmd "Repositório Flathub" "$LOG_DIR/flatpak_remote.log" \
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    run_cmd "Runtime Flatpak atualizado" "$LOG_DIR/flatpak_update.log" \
        flatpak update --noninteractive -y
}

flatpak_install() {
    title "Instalando aplicativos Flatpak (${#FLATPAK_APPS[@]})"
    [ "${#FLATPAK_APPS[@]}" -eq 0 ] && { record SKIP "Flatpak (lista vazia)"; return; }
    have flatpak || { record FAIL "Flatpak ausente; aplicativos não instalados"; return; }
    local app
    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak info "$app" >/dev/null 2>&1; then
            record SKIP "Flatpak $app (já instalado)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Flatpak $app (dry-run)"; continue
        fi
        confirm "Instalar Flatpak $app?" || { record SKIP "Flatpak $app (recusado)"; continue; }
        run_cmd "Flatpak $app" "$LOG_DIR/flatpak_${app}.log" \
            flatpak install --noninteractive -y flathub "$app"
    done
}

# --- Extensões GNOME ------------------------------------------------------
gnome_shell_major() {
    gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -n1
}

install_gnome_extensions() {
    title "Instalando extensões GNOME (${#GNOME_EXTENSIONS[@]})"
    [ "${#GNOME_EXTENSIONS[@]}" -eq 0 ] && { record SKIP "Extensões GNOME (lista vazia)"; return; }
    have curl || { record FAIL "curl ausente; não é possível baixar extensões"; return; }
    have unzip || { record FAIL "unzip ausente; instale o pacote unzip"; return; }

    local shell_ver; shell_ver="$(gnome_shell_major)"
    [ -z "$shell_ver" ] && { record FAIL "Não foi possível detectar a versão do GNOME Shell"; return; }
    info "GNOME Shell detectado: $shell_ver"

    local uuid info_json dl dest
    for uuid in "${GNOME_EXTENSIONS[@]}"; do
        dest="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"

        if [ -d "$dest" ]; then
            record SKIP "Extensão $uuid (já instalada)"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Extensão $uuid (dry-run)"; continue
        fi
        confirm "Instalar extensão GNOME $uuid?" || { record SKIP "$uuid (recusada)"; continue; }

        info_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_ver}" 2>>"$LOG_DIR/extensions.log")"
        dl="$(printf '%s' "$info_json" | grep -oE '"(/download-extension|https?://)[^"]*\.zip[^"]*"' | tr -d '"' | head -n1)"
        if [ -z "$dl" ]; then
            record FAIL "Extensão $uuid (sem versão para GNOME $shell_ver)"; continue
        fi
        case "$dl" in
            /*) dl="https://extensions.gnome.org${dl}" ;;
        esac

        mkdir -p "$dest"
        if curl -fsSL "$dl" -o "$dest/ext.zip" 2>>"$LOG_DIR/extensions.log" \
            && unzip -q -o "$dest/ext.zip" -d "$dest" >>"$LOG_DIR/extensions.log" 2>&1; then
            rm -f "$dest/ext.zip"
            record OK "Extensão $uuid instalada"
            # Tenta habilitar (pode exigir relogin para extensões de shell).
            gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
        else
            rm -rf "$dest"
            record FAIL "Extensão $uuid (falha no download/extração; veja $LOG_DIR/extensions.log)"
        fi
    done
    info "Algumas extensões só ficam ativas após sair e entrar novamente."
}

# --- Ferramentas de desenvolvimento --------------------------------------

# Escreve as variáveis de ambiente em um único arquivo e garante que o
# ~/.bashrc (e ~/.zshrc, se existir) o carregue.
setup_shell_env() {
    title "Configurando variáveis de ambiente do shell"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Variáveis de shell em $ENV_FILE (dry-run)"; return
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<EOF
# Variáveis de ambiente das ferramentas instaladas.
# Gerado por instalar-ubuntu-26-04.sh — edite com cuidado.

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

    # Garante o carregamento em shells interativos e de login.
    local marker="# --- instalar-ubuntu environment ---"
    local load_line="[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\""
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
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
    # ~/.profile cobre sessões de login que não leem .bashrc.
    if [ -f "$HOME/.profile" ] && ! grep -qF "$ENV_FILE" "$HOME/.profile"; then
        printf '\n# --- instalar-ubuntu environment ---\n[ -f "%s" ] && . "%s"\n' \
            "$ENV_FILE" "$ENV_FILE" >> "$HOME/.profile"
        record OK "Carregamento adicionado em $HOME/.profile"
    fi

    # Aplica já na sessão atual do script.
    # shellcheck disable=SC1090
    . "$ENV_FILE" 2>/dev/null || true
}

install_opencode() {
    title "Instalando opencode"
    if [ -x "$HOME/.opencode/bin/opencode" ]; then
        record SKIP "opencode (já instalado)"
        return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "opencode (dry-run)"; return
    fi
    confirm "Instalar o opencode?" || { record SKIP "opencode (recusado)"; return; }
    # --no-modify-path: o PATH é gerenciado pelo nosso env.sh.
    run_cmd "opencode" "$LOG_DIR/opencode.log" \
        bash -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path'
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

    # Carrega o nvm para instalar o Node. Necessário também por causa do
    # "set -u": o script do nvm referencia NVM_* e quebraria sem carregar.
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
    fi

    if [ -n "${NVM_NODE_VERSION:-}" ] && command -v nvm >/dev/null 2>&1; then
        # Aceita "lts", "lts/*", "node" ou uma versão exata (ex.: 22).
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
    # Disponibiliza "dotnet-install" como comando no PATH do usuário.
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
        run_cmd ".NET SDK ${channel}" "$LOG_DIR/dotnet_${channel}.log" \
            "$installer" --channel "$channel" --install-dir "$HOME/.dotnet"
    done
    info "Para outras versões, use: dotnet-install --channel <versao>"
    info "(instala sempre em \$DOTNET_INSTALL_DIR = ~/.dotnet; sem precisar de flags)"
    info "Liste o instalado com: dotnet --list-sdks"
}

cleanup() {
    title "Limpeza"
    confirm "Executar autoremove e clean?" || { record SKIP "Limpeza (recusada)"; return; }
    run_cmd "apt autoremove" "$LOG_DIR/autoremove.log" "${SUDO[@]}" apt-get autoremove -y
    run_cmd "apt clean" "$LOG_DIR/clean.log" "${SUDO[@]}" apt-get clean
}

# ===========================================================================
# RESUMO
# ===========================================================================

print_summary() {
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
            -h|--help)        usage; exit 0 ;;
            *) err "Opção desconhecida: $1"; usage; exit 2 ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    mkdir -p "$LOG_DIR" "$DEB_DIR"
    printf 'Resumo da instalação - %s\n\n' "$(date)" > "$SUMMARY"

    printf '%s\n' "${C_BOLD}Instalador Ubuntu 26.04${C_RESET}"
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
        apt)        apt_refresh; apt_upgrade; apt_install ;;
        repos)      add_third_party_repos ;;
        ppa)        add_ppas ;;
        deb)        install_direct_debs ;;
        flatpak)    flatpak_setup; flatpak_install ;;
        extensions) install_gnome_extensions ;;
        dev)        setup_shell_env; install_opencode; install_nvm; install_dotnet ;;
        manual)     install_manual_downloads ;;
        cleanup)    cleanup ;;
        "")
            apt_refresh
            apt_upgrade
            apt_install
            add_third_party_repos
            add_ppas
            install_direct_debs
            flatpak_setup
            flatpak_install
            install_gnome_extensions
            setup_shell_env
            install_opencode
            install_nvm
            install_dotnet
            cleanup
            # Por último: depende de interação manual do usuário.
            install_manual_downloads
            ;;
        *) err "Grupo inválido para --only: $ONLY"; exit 2 ;;
    esac

    print_summary
}

main "$@"
