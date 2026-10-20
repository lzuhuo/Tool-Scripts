#!/usr/bin/env bash
#
# instalar_zorin.sh
# ---------------------------------------------------------------------------
# Provisiona uma instalação limpa do Zorin OS 18.x (baseado em Ubuntu 24.04).
#
# Estratégia de instalação (preferência decrescente):
#   1. Pacotes dos repositórios oficiais (Zorin/Ubuntu universe/main).
#   2. PPAs do Launchpad e repositórios APT oficiais de terceiros
#      (Ulauncher, Chrome, VS Code, Edge, DBeaver, AnyDesk) e pacotes
#      .deb avulsos (Zoom, FDM, Ferdium, WiFiman).
#      Vantagem: atualizam junto com "apt upgrade".
#   3. Flatpak/Flathub apenas para o que não tem pacote APT confiável
#      (Postman, WinBox).
#
# Recursos:
#   - Barra de progresso global e por-etapa com previsão de tempo (ETA).
#   - Autorização gráfica (janela de senha) quando não há terminal.
#   - Logs e cache de .deb em ~/.local, fora do repositório.
#   - Tratamento de erro real, contagem de falhas e resumo final.
#   - Idempotente: pode ser reexecutado sem quebrar.
#   - Auto-atualização opcional a partir de URL do repositório Git.
#
# Uso:
#   ./instalar_zorin.sh [opções]
#
# Opções:
#   -y, --yes         Não perguntar nada (modo não interativo).
#   -n, --dry-run     Mostra o que faria, sem alterar o sistema.
#   --no-upgrade      Pula o "apt upgrade" (só instala o que falta).
#   --no-self-update  Não tenta atualizar o script pelo Git.
#   --only <grupo>    Executa só um grupo:
#                     apt|repos|ppa|deb|flatpak|extensions|dev|manual|cleanup
#   --live-log        Mostra o log em tempo real (tail -f) numa janela separada.
#   --no-color        Desativa cores ANSI (útil para logs de CI/CD).
#   -v, --verbose     Mostra a saída do apt em tempo real (sem redirecionar).
#   -h, --help        Mostra esta ajuda.
#
# Requisitos: Zorin OS 18 (ou Ubuntu 24.04+), internet, usuário com sudo.
# ---------------------------------------------------------------------------

set -uo pipefail

# ===========================================================================
# CONFIGURAÇÃO
# ===========================================================================

# --- Pacotes dos repositórios oficiais ------------------------------------
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
    network-manager-gnome            # applet do NetworkManager (substitui o antigo network-manager-applet, removido no 24.04)
    inetutils-telnet   # cliente telnet
    inetutils-traceroute
    # Obs.: "inetutils-ping" conflita com o iputils-ping padrão,
    # por isso o ping nativo foi mantido.
)

# --- Repositórios APT oficiais de terceiros ------------------------------
# Formato: "Nome|URL_da_chave|URL_do_repo|suite|componentes|pacotes"
THIRD_PARTY_REPOS=(
    "Google Chrome|https://dl.google.com/linux/linux_signing_key.pub|https://dl.google.com/linux/chrome/deb/|stable|main|google-chrome-stable"
    "Visual Studio Code|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/repos/code|stable|main|code"
    "Microsoft Edge|https://packages.microsoft.com/keys/microsoft.asc|https://packages.microsoft.com/repos/edge|stable|main|microsoft-edge-stable"
    "DBeaver CE|https://dbeaver.io/debs/dbeaver.gpg.key|https://dbeaver.io/debs/dbeaver-ce/|/||dbeaver-ce"
    "AnyDesk|https://keys.anydesk.com/repos/DEB-GPG-KEY|http://deb.anydesk.com/|all|main|anydesk"
)

# --- PPAs (repositórios pessoais do Launchpad) ---------------------------
# Formato: "Nome|ppa:usuario/ppa|pacotes"
PPAS=(
    "Ulauncher|ppa:agornostal/ulauncher|ulauncher"
)

# --- Pacotes .deb avulsos -------------------------------------------------
# Formato: "Nome|URL|arquivo_local|pacote_dpkg"
DIRECT_DEBS=(
    "Zoom|https://zoom.us/client/latest/zoom_amd64.deb|zoom_amd64.deb|zoom"
    "Free Download Manager|https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.deb|freedownloadmanager.deb|freedownloadmanager"
    "Ferdium|gh:ferdium/ferdium-app|ferdium_amd64.deb|ferdium"
    "WiFiman Desktop|https://desktop.wifiman.com/wifiman-desktop-1.3.0-amd64.deb|wifiman-desktop.deb|wifiman-desktop"
)

# --- Download manual (modal de navegador) --------------------------------
# Formato: "Nome|URL_da_pagina|padrao_do_arquivo|pacote_dpkg"
MANUAL_DOWNLOADS=(
    "Zoiper 5|https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-deb|Zoiper*.deb|zoiper5"
)

# --- Extensões GNOME (extensions.gnome.org) ------------------------------
GNOME_EXTENSIONS=(
    blur-my-shell@aunetx
    dash-to-dock@micxgx.gmail.com
    Vitals@CoreCoding.com
    show-desktop-button@amivaleo
    compiz-alike-magic-lamp-effect@hermes83.github.com
    compiz-windows-effect@hermes83.github.com
)

# --- Ferramentas de desenvolvimento --------------------------------------
NVM_VERSION="v0.40.8"          # versão do nvm a instalar
NVM_NODE_VERSION="lts"         # versão do Node a instalar após o nvm ("" pula)

# .NET SDK — instale os canais que quiser (side-by-side). Ex.: (8.0 9.0 10.0)
DOTNET_CHANNELS=(10.0 8.0)

# Arquivo único com as variáveis de ambiente, carregado pelo ~/.bashrc.
ENV_FILE="$HOME/.config/instalar-zorin/env.sh"

# --- Aplicativos via Flatpak (Flathub) -----------------------------------
FLATPAK_APPS=(
    com.getpostman.Postman
    com.mikrotik.WinBox
)

# --- Auto-atualização do script pelo repositório Git ---------------------
REPO_RAW_URL=""
SELF_UPDATE="yes"

# --- Caminhos -------------------------------------------------------------
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/instalar-zorin"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/instalar-zorin"
LOG_DIR="$DATA_HOME/logs"
DEB_DIR="$CACHE_HOME/deb"
SUMMARY="$LOG_DIR/summary.log"

# --- Cores ----------------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-0}" -eq 0 ]; then
    C_RESET=$'\033[0m'; C_OK=$'\033[32m'; C_ERR=$'\033[31m'
    C_WARN=$'\033[33m'; C_INFO=$'\033[36m'; C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'; C_BAR=$'\033[36m'
else
    C_RESET=""; C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_BOLD=""
    C_DIM=""; C_BAR=""
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
LIVE_LOG=0      # 1 = tail -f do log principal em paralelo
NO_COLOR=0      # 1 = desativa cores ANSI
VERBOSE=0       # 1 = mostra stderr/stdout do apt em tempo real

# Ambiente não interativo para o apt: evita prompts que travam a instalação
# (ex.: o pacote "code" pergunta sobre adicionar o repositório da Microsoft
# mesmo com DEBIAN_FRONTEND=noninteractive, pois usa debconf).
APT_ENV=(
    env
    DEBIAN_FRONTEND=noninteractive
    DEBCONF_NONINTERACTIVE_SEEN=true
    APT_LISTCHANGES_FRONTEND=none
    NEEDRESTART_MODE=a          # reinicia serviços automaticamente, sem prompt
    UCF_FORCE_CONFFOLD=1        # não pergunta sobre arquivos de configuração
)
APT_OPTS=(
    -y
    -o Dpkg::Options::=--force-confdef
    -o Dpkg::Options::=--force-confold
    -o Acquire::Retries=3
)

# ===========================================================================
# INTERFACE DE PROGRESSO
# ===========================================================================
# O acompanhamento do progresso é feito em três camadas simultâneas:
#   1. Cabeçalho com etapa atual (X/N) e barra de progresso global.
#   2. Barra por-etapa com contagem de itens (ex.: pacotes) e ETA.
#   3. Spinner com última ação em execução, para nunca parecer travado.

TERM_WIDTH="$( (tput cols 2>/dev/null || echo 80) )"
[ "$TERM_WIDTH" -lt 60 ] && TERM_WIDTH=60
SPINNER_PID=""
SPINNER_TEXT=""
CURRENT_STAGE=""
CURRENT_STAGE_NO=0
TOTAL_STAGES=1
STAGE_START_TS=0
GLOBAL_START_TS=0

_spinner() {
    # Roda em background; apenas desenha enquanto o trabalho acontece.
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
    # Limpa a linha do spinner.
    printf '\r%-*s\r' "$TERM_WIDTH" "" >&2
}

# draw_bar: desenha barra de progresso — apenas em TTY real.
draw_bar() {
    [ -t 2 ] || return 0
    spinner_stop
    local label="$1" current="$2" total="$3"
    [ "${total:-0}" -le 0 ] && return 0
    [ "$current" -gt "$total" ] && current="$total"

    local pct=$(( current * 100 / total ))
    local filled=$(( pct * 40 / 100 ))
    local empty=$(( 40 - filled ))
    local bar
    bar="$(printf '%0.s█' $(seq 1 "$filled" 2>/dev/null))"
    bar+="${C_DIM}$(printf '%0.s░' $(seq 1 "$empty" 2>/dev/null))${C_RESET}"

    # ETA baseado no tempo decorrido da etapa atual.
    local eta=""; local now; now="$(date +%s)"
    if [ -n "$STAGE_START_TS" ] && [ "$current" -gt 0 ]; then
        local elapsed=$(( now - STAGE_START_TS ))
        local remaining=$(( (elapsed * total / current) - elapsed ))
        if [ "$remaining" -ge 0 ]; then
            if [ "$remaining" -ge 60 ]; then
                eta="$(printf '~%dmin' $(( remaining / 60 )) )"
            else
                eta="~${remaining}s"
            fi
        fi
    fi

    # Limpa a linha antes de reescrever para não misturar com mensagens.
    printf '\r%-*s\r' "$TERM_WIDTH" "" >&2
    printf '%s%-22s%s [%s%s%s] %3d%%  %d/%d %s' \
        "$C_BOLD" "$label" "$C_RESET" \
        "$C_BAR" "$bar" "$C_RESET" \
        "$pct" "$current" "$total" "$eta" >&2
}

end_stage_bar() {
    [ -t 2 ] || return 0
    printf '\r%-*s\r' "$TERM_WIDTH" "" >&2
}

# Inicia uma nova etapa (deve ser chamada no início de cada função de fase).
begin_stage() {
    # begin_stage <numero> <total_de_etapas> <nome_da_etapa>
    CURRENT_STAGE_NO="$1"
    CURRENT_STAGE="$3"
    TOTAL_STAGES="$2"
    STAGE_START_TS="$(date +%s)"

    # Cabeçalho da etapa com progresso global.
    local gpct=$(( (CURRENT_STAGE_NO - 1) * 100 / TOTAL_STAGES ))
    printf '\n%s╔══ Etapa %d/%d [%3d%%] %s\n' \
        "$C_BOLD" "$CURRENT_STAGE_NO" "$TOTAL_STAGES" "$gpct" "$CURRENT_STAGE" \
        >&2
    printf '%s║%s' "$C_DIM" "$C_RESET" >&2
    # Mini-barra global.
    local filled=$(( gpct * 30 / 100 )) i
    for (( i=0; i<30; i++ )); do
        if [ "$i" -lt "$filled" ]; then printf '%s█%s' "$C_BAR" "$C_RESET" >&2
        else printf '%s░%s' "$C_DIM" "$C_RESET" >&2; fi
    done
    printf ' %d%%\n%s╚══%s\n' "$gpct" "$C_DIM" "$C_RESET" >&2
}

stage_done() {
    end_stage_bar
    local elapsed=$(( $(date +%s) - STAGE_START_TS ))
    printf '%s  ✔ Etapa concluída em %ds%s\n' "$C_OK" "$elapsed" "$C_RESET" >&2
}

# ===========================================================================
# FUNÇÕES BÁSICAS
# ===========================================================================

info()  { spinner_stop; printf '%s\n' "${C_INFO}$*${C_RESET}"; }
warn()  { spinner_stop; printf '%s\n' "${C_WARN}$*${C_RESET}" >&2; }
err()   { spinner_stop; printf '%s\n' "${C_ERR}$*${C_RESET}" >&2; }
title() { spinner_stop; printf '\n%s\n' "${C_BOLD}==> $*${C_RESET}"; }

record() {
    spinner_stop
    # Limpa a linha da barra antes de imprimir a mensagem.
    end_stage_bar
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
        zenity --question --title="Instalação Zorin OS" --width=420 --text="$question" 2>/dev/null
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
    if [ "$VERBOSE" -eq 1 ]; then
        # Modo verbose: mostra a saída do comando em tempo real e duplica no log.
        "$@" 2>&1 | tee -a "$logfile"
        if [ "${PIPESTATUS[0]:-1}" -eq 0 ]; then
            record OK "$label"; return 0
        fi
        record FAIL "$label (veja $logfile)"; return 1
    fi
    # Modo normal: spinner com o rótulo enquanto o comando roda.
    spinner_start "$label"
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
        if [ "${ID:-}" = "zorin" ]; then
            record OK "Sistema: Zorin OS ${VERSION_ID:-?} (${UBUNTU_CODENAME:-?})"
        elif [ "${ID:-}" = "ubuntu" ]; then
            record OK "Sistema: Ubuntu ${VERSION_ID:-?} (compatível)"
        else
            record SKIP "Sistema não é Zorin/Ubuntu (${ID:-?}); seguindo mesmo assim"
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
    begin_stage 1 14 "Índices de pacotes (apt update)"
    confirm "Executar 'apt update'?" || { record SKIP "apt update (recusado)"; stage_done; return; }
    run_cmd "apt update" "$LOG_DIR/apt_update.log" "${SUDO[@]}" apt-get update
    stage_done
}

apt_upgrade() {
    begin_stage 2 14 "Atualização de pacotes (apt upgrade)"
    [ "$DO_UPGRADE" -eq 1 ] || { record SKIP "apt upgrade desativado"; stage_done; return; }
    confirm "Executar 'apt upgrade'? Isso pode demorar." || { record SKIP "apt upgrade (recusado)"; stage_done; return; }
    run_cmd "apt upgrade" "$LOG_DIR/apt_upgrade.log" \
        "${APT_ENV[@]}" "${SUDO[@]}" apt-get upgrade "${APT_OPTS[@]}"
    stage_done
}

apt_install() {
    begin_stage 3 14 "Pacotes oficiais"
    local missing=() p
    for p in "${APT_PACKAGES[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        record SKIP "Pacotes oficiais (todos já instalados)"; stage_done; return
    fi
    info "Faltando: ${#missing[@]} pacote(s)"
    confirm "Instalar ${#missing[@]} pacote(s) via apt?" || { record SKIP "Pacotes oficiais (recusado)"; stage_done; return; }

    # Progresso item a item para dar feedback real ao usuário.
    local total="${#missing[@]}" idx=0
    for p in "${missing[@]}"; do
        idx=$((idx + 1))
        draw_bar "apt install" "$((idx - 1))" "$total"
        spinner_start "Instalando $p ($idx/$total)"
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$p (dry-run)"
        elif run_cmd "$p" "$LOG_DIR/apt_install.log" \
            "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" --no-install-recommends "$p"; then
            :
        fi
        draw_bar "apt install" "$idx" "$total"
    done
    stage_done
}

# --- Repositórios APT de terceiros ---------------------------------------
add_third_party_repos() {
    begin_stage 4 14 "Repositórios APT de terceiros"
    [ "${#THIRD_PARTY_REPOS[@]}" -eq 0 ] && { record SKIP "Sem repositórios de terceiros"; stage_done; return; }

    local tmp; tmp="$(mktemp -d)"
    local entry name key_url repo_url suite components pkgs base keyring script
    script="$tmp/setup.sh"
    : > "$script"

    local total="${#THIRD_PARTY_REPOS[@]}" idx=0
    for entry in "${THIRD_PARTY_REPOS[@]}"; do
        idx=$((idx + 1))
        draw_bar "Configurando repos" "$((idx - 1))" "$total"
        IFS='|' read -r name key_url repo_url suite components pkgs <<< "$entry"
        base="$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-')"
        keyring="/usr/share/keyrings/${base}.gpg"

        printf 'echo "  - %s"\n' "$name" >> "$script"
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Repositório $name (dry-run)"
            draw_bar "Configurando repos" "$idx" "$total"
            continue
        fi
        if have curl; then
            curl -fsSL "$key_url" -o "$tmp/${base}.key" 2>>"$LOG_DIR/repos.log" \
                || { record FAIL "Chave de $name (veja $LOG_DIR/repos.log)"; draw_bar "Configurando repos" "$idx" "$total"; continue; }
        else
            wget -qO "$tmp/${base}.key" "$key_url" 2>>"$LOG_DIR/repos.log" \
                || { record FAIL "Chave de $name (veja $LOG_DIR/repos.log)"; draw_bar "Configurando repos" "$idx" "$total"; continue; }
        fi

        {
            printf 'gpg --dearmor --yes -o %s %s\n' "'$keyring'" "'$tmp/${base}.key'"
            printf 'chmod 0644 %s\n' "'$keyring'"
            if [ -n "$components" ]; then
                printf "printf '%%s\\n' 'deb [signed-by=%s] %s %s %s' > '/etc/apt/sources.list.d/%s.list'\n" \
                    "$keyring" "$repo_url" "$suite" "$components" "$base"
            else
                printf "printf '%%s\\n' 'deb [signed-by=%s] %s %s' > '/etc/apt/sources.list.d/%s.list'\n" \
                    "$keyring" "$repo_url" "$suite" "$base"
            fi
        } >> "$script"
        record OK "Repositório $name configurado"
        draw_bar "Configurando repos" "$idx" "$total"
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
    stage_done

    # Instala os pacotes de cada repositório.
    begin_stage 5 14 "Aplicativos dos repositórios de terceiros"

    # Pré-responde o debconf de pacotes que insistem em abrir diálogo mesmo
    # em modo noninteractive (ex.: o "code" pergunta se deve adicionar o
    # repositório da Microsoft). Sem isto a instalação trava esperando input.
    if [ "$DRY_RUN" -eq 0 ]; then
        printf 'code code/add-microsoft-repo boolean true\n
microsoft-edge-stable microsoft-edge-stable/stable-channel boolean true\n
microsoft-edge-stable microsoft-edge-stable/add-repo boolean true\n' \
            | "${SUDO[@]}" debconf-set-selections 2>/dev/null || true
    fi

    total="${#THIRD_PARTY_REPOS[@]}"; idx=0
    for entry in "${THIRD_PARTY_REPOS[@]}"; do
        idx=$((idx + 1))
        IFS='|' read -r name key_url repo_url suite components pkgs <<< "$entry"
        local p installed=0
        for p in $pkgs; do pkg_installed "$p" && installed=1; done
        if [ "$installed" -eq 1 ]; then
            record SKIP "$name (já instalado)"
            draw_bar "Instalando apps" "$idx" "$total"
            continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Instalação $name (dry-run): $pkgs"
            draw_bar "Instalando apps" "$idx" "$total"
            continue
        fi
        confirm "Instalar $name?" || { record SKIP "$name (recusado)"; draw_bar "Instalando apps" "$idx" "$total"; continue; }
        # shellcheck disable=SC2086
        run_cmd "Instalação $name" "$LOG_DIR/apt_third_${name// /_}.log" \
            "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" $pkgs
        draw_bar "Instalando apps" "$idx" "$total"
    done
    stage_done
}

# --- PPAs ----------------------------------------------------------------
add_ppas() {
    begin_stage 6 14 "PPAs (Launchpad)"
    [ "${#PPAS[@]}" -eq 0 ] && { record SKIP "Sem PPAs configuradas"; stage_done; return; }
    have add-apt-repository || { record FAIL "add-apt-repository ausente (instale software-properties-common)"; stage_done; return; }

    # O add-apt-repository consulta a API do Launchpad para resolver o PPA.
    # Em redes que bloqueiam launchpad.net isso gera um FAIL confuso; avisamos.
    if ! curl -fsS --max-time 8 -o /dev/null https://api.launchpad.net/1.0/ 2>/dev/null; then
        warn "Launchpad (api.launchpad.net) inacessível nesta rede."
        warn "Os PPAs serão pulados — o restante da instalação continua normalmente."
    fi

    local entry name ppa pkgs total="${#PPAS[@]}" idx=0
    for entry in "${PPAS[@]}"; do
        idx=$((idx + 1))
        IFS='|' read -r name ppa pkgs <<< "$entry"
        local p installed=0
        for p in $pkgs; do pkg_installed "$p" && installed=1; done
        if [ "$installed" -eq 1 ]; then
            record SKIP "$name (já instalado)"; draw_bar "Configurando PPA" "$idx" "$total"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "PPA $name (dry-run): $ppa"; draw_bar "Configurando PPA" "$idx" "$total"; continue
        fi
        confirm "Adicionar e instalar do $name ($ppa)?" || { record SKIP "$name (recusado)"; draw_bar "Configurando PPA" "$idx" "$total"; continue; }
        if run_cmd "PPA $name" "$LOG_DIR/ppa_${name// /_}.log" \
            "${SUDO[@]}" add-apt-repository -y "$ppa"; then
            run_cmd "apt update (após PPA $name)" "$LOG_DIR/apt_update.log" "${SUDO[@]}" apt-get update
            # shellcheck disable=SC2086
            run_cmd "Instalação $name (via PPA)" "$LOG_DIR/ppa_install_${name// /_}.log" \
                "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" $pkgs
        else
            # Distingue falha de rede de falha real do PPA.
            if grep -qE 'TimeoutError|Connection timed out|Temporary failure|Could not connect' \
                "$LOG_DIR/ppa_${name// /_}.log" 2>/dev/null; then
                record SKIP "$name (rede/Launchpad indisponível; tente novamente depois)"
            elif grep -qE '404|not found|does not exist' "$LOG_DIR/ppa_${name// /_}.log" 2>/dev/null; then
                record SKIP "$name (PPA inexistente para esta versão: $ppa)"
            fi
        fi
        draw_bar "Configurando PPA" "$idx" "$total"
    done
    stage_done
}

# --- Pacotes .deb avulsos -------------------------------------------------
github_latest_deb() {
    local repo="$1" suffix="${2:-amd64.deb}"
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -oE '"browser_download_url": "[^"]+"' \
        | sed -E 's/.*"(https:[^"]+)"/\1/' \
        | grep -E "${suffix}$" | head -n1
}

manual_download() {
    local name="$1" url="$2" pattern="$3"
    MANUAL_FILE=""
    local dl_dir; dl_dir="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
    mkdir -p "$dl_dir"

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
        "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" wmctrl >>"$LOG_DIR/manual.log" 2>&1 || true
    fi

    info "Abrindo o navegador na página de download de $name."
    info "Baixe o arquivo '${pattern}' — o script detecta e continua sozinho."

    profile="$(mktemp -d)"
    local win_title="Download $name"
    "$browser" --user-data-dir="$profile" --new-window --app="$url" \
        >>"$LOG_DIR/manual.log" 2>&1 &
    local bpid=$!

    local found="" waited=0
    while [ "$waited" -lt 900 ]; do
        # shellcheck disable=SC2086
        found="$(find "$dl_dir" -maxdepth 1 -type f -name "$pattern" \
                    ! -name '*.crdownload' ! -name '*.part' \
                    -mmin -30 2>/dev/null | head -n1)"
        if [ -n "$found" ] && [ -s "$found" ]; then
            local s1 s2
            s1="$(stat -c%s "$found" 2>/dev/null || echo 0)"
            sleep 2
            s2="$(stat -c%s "$found" 2>/dev/null || echo 0)"
            if [ "$s1" = "$s2" ] && [ "$s1" -gt 0 ]; then
                break
            fi
        fi
        spinner_start "Aguardando download de $name (${waited}s)"
        sleep 2; waited=$((waited + 2))
    done

    if have wmctrl; then
        wmctrl -c "$win_title" 2>/dev/null || true
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
    begin_stage 14 14 "Downloads manuais (navegador)"
    local entry name url pattern pkg total="${#MANUAL_DOWNLOADS[@]}" idx=0
    for entry in "${MANUAL_DOWNLOADS[@]}"; do
        idx=$((idx + 1))
        IFS='|' read -r name url pattern pkg <<< "$entry"
        if pkg_installed "$pkg"; then
            record SKIP "$name (já instalado)"; draw_bar "Download manual" "$idx" "$total"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$name (dry-run): modal em $url"; draw_bar "Download manual" "$idx" "$total"; continue
        fi
        confirm "Abrir o navegador para baixar $name agora?" \
            || { record SKIP "$name (recusado)"; draw_bar "Download manual" "$idx" "$total"; continue; }

        manual_download "$name" "$url" "$pattern" || continue
        [ -n "$MANUAL_FILE" ] || { record FAIL "$name (arquivo não encontrado)"; draw_bar "Download manual" "$idx" "$total"; continue; }

        if run_cmd "Instalação $name" "$LOG_DIR/deb_install.log" \
            "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" "$MANUAL_FILE"; then
            info "Arquivo baixado mantido em: $MANUAL_FILE"
        fi
        draw_bar "Download manual" "$idx" "$total"
    done
    stage_done
}

install_direct_debs() {
    begin_stage 7 14 "Pacotes .deb avulsos"
    [ "${#DIRECT_DEBS[@]}" -eq 0 ] && { record SKIP "Pacotes .deb (lista vazia)"; stage_done; return; }

    local entry name url file pkg dest real_url total="${#DIRECT_DEBS[@]}" idx=0
    for entry in "${DIRECT_DEBS[@]}"; do
        idx=$((idx + 1))
        IFS='|' read -r name url file pkg <<< "$entry"
        dest="$DEB_DIR/$file"

        if pkg_installed "$pkg"; then
            record SKIP "$name (já instalado)"; draw_bar "Instalando .deb" "$idx" "$total"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Instalação $name (dry-run)"; draw_bar "Instalando .deb" "$idx" "$total"; continue
        fi
        confirm "Baixar e instalar $name?" || { record SKIP "$name (recusado)"; draw_bar "Instalando .deb" "$idx" "$total"; continue; }

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
                record FAIL "$name (não foi possível resolver o release no GitHub)"
                draw_bar "Instalando .deb" "$idx" "$total"
                continue
            fi
        fi

        # Rebaixa se o arquivo local estiver vazio/corrompido.
        if [ -n "$real_url" ] && [ ! -s "$dest" ]; then
            spinner_start "Baixando $name..."
            if have curl; then
                curl -fL --retry 3 -o "$dest" "$real_url" >>"$LOG_DIR/deb_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/deb_download.log)"; draw_bar "Instalando .deb" "$idx" "$total"; continue; }
            else
                wget -qO "$dest" "$real_url" >>"$LOG_DIR/deb_download.log" 2>&1 \
                    || { record FAIL "Download $name (veja $LOG_DIR/deb_download.log)"; draw_bar "Instalando .deb" "$idx" "$total"; continue; }
            fi
        fi

        run_cmd "Instalação $name" "$LOG_DIR/deb_install.log" \
            "${APT_ENV[@]}" "${SUDO[@]}" apt-get install "${APT_OPTS[@]}" "$dest"
        draw_bar "Instalando .deb" "$idx" "$total"
    done

    run_cmd "Correção de dependências (apt -f)" "$LOG_DIR/deb_fix.log" \
        "${APT_ENV[@]}" "${SUDO[@]}" apt-get -f install "${APT_OPTS[@]}"
    stage_done
}

# --- Flatpak --------------------------------------------------------------
flatpak_setup() {
    begin_stage 8 14 "Flatpak e Flathub"
    have flatpak || { record FAIL "Flatpak não instalado; pulando"; stage_done; return 1; }
    confirm "Adicionar o repositório Flathub?" || { record SKIP "Flathub (recusado)"; stage_done; return; }
    run_cmd "Repositório Flathub" "$LOG_DIR/flatpak_remote.log" \
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    run_cmd "Runtime Flatpak atualizado" "$LOG_DIR/flatpak_update.log" \
        flatpak update --noninteractive -y
    stage_done
}

flatpak_install() {
    begin_stage 9 14 "Aplicativos Flatpak"
    [ "${#FLATPAK_APPS[@]}" -eq 0 ] && { record SKIP "Flatpak (lista vazia)"; stage_done; return; }
    have flatpak || { record FAIL "Flatpak ausente; aplicativos não instalados"; stage_done; return; }
    local app total="${#FLATPAK_APPS[@]}" idx=0
    for app in "${FLATPAK_APPS[@]}"; do
        idx=$((idx + 1))
        if flatpak info "$app" >/dev/null 2>&1; then
            record SKIP "Flatpak $app (já instalado)"; draw_bar "Flatpak" "$idx" "$total"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Flatpak $app (dry-run)"; draw_bar "Flatpak" "$idx" "$total"; continue
        fi
        confirm "Instalar Flatpak $app?" || { record SKIP "Flatpak $app (recusado)"; draw_bar "Flatpak" "$idx" "$total"; continue; }
        spinner_start "Instalando Flatpak $app..."
        run_cmd "Flatpak $app" "$LOG_DIR/flatpak_${app}.log" \
            flatpak install --noninteractive -y flathub "$app"
        draw_bar "Flatpak" "$idx" "$total"
    done
    stage_done
}

# --- Extensões GNOME ------------------------------------------------------
gnome_shell_major() {
    gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -n1
}

install_gnome_extensions() {
    begin_stage 10 14 "Extensões GNOME"
    [ "${#GNOME_EXTENSIONS[@]}" -eq 0 ] && { record SKIP "Extensões GNOME (lista vazia)"; stage_done; return; }
    have curl || { record FAIL "curl ausente; não é possível baixar extensões"; stage_done; return; }
    have unzip || { record FAIL "unzip ausente; instale o pacote unzip"; stage_done; return; }

    local shell_ver; shell_ver="$(gnome_shell_major)"
    [ -z "$shell_ver" ] && { record FAIL "Não foi possível detectar a versão do GNOME Shell"; stage_done; return; }
    info "GNOME Shell detectado: $shell_ver"

    local uuid info_json dl dest total="${#GNOME_EXTENSIONS[@]}" idx=0
    for uuid in "${GNOME_EXTENSIONS[@]}"; do
        idx=$((idx + 1))
        dest="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"

        if [ -d "$dest" ]; then
            record SKIP "Extensão $uuid (já instalada)"; draw_bar "Extensões" "$idx" "$total"; continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Extensão $uuid (dry-run)"; draw_bar "Extensões" "$idx" "$total"; continue
        fi
        confirm "Instalar extensão GNOME $uuid?" || { record SKIP "$uuid (recusada)"; draw_bar "Extensões" "$idx" "$total"; continue; }

        spinner_start "Baixando extensão $uuid..."
        info_json="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_ver}" 2>>"$LOG_DIR/extensions.log")"
        dl="$(printf '%s' "$info_json" | grep -oE '"(/download-extension|https?://)[^"]*\.zip[^"]*"' | tr -d '"' | head -n1)"
        if [ -z "$dl" ]; then
            record FAIL "Extensão $uuid (sem versão para GNOME $shell_ver)"; draw_bar "Extensões" "$idx" "$total"; continue
        fi
        case "$dl" in
            /*) dl="https://extensions.gnome.org${dl}" ;;
        esac

        mkdir -p "$dest"
        if curl -fsSL "$dl" -o "$dest/ext.zip" 2>>"$LOG_DIR/extensions.log" \
            && unzip -q -o "$dest/ext.zip" -d "$dest" >>"$LOG_DIR/extensions.log" 2>&1; then
            rm -f "$dest/ext.zip"
            record OK "Extensão $uuid instalada"
            gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
        else
            rm -rf "$dest"
            record FAIL "Extensão $uuid (falha no download/extração; veja $LOG_DIR/extensions.log)"
        fi
        draw_bar "Extensões" "$idx" "$total"
    done
    info "Algumas extensões só ficam ativas após sair e entrar novamente."
    stage_done
}

# --- Ferramentas de desenvolvimento --------------------------------------

setup_shell_env() {
    begin_stage 11 14 "Variáveis de ambiente do shell"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Variáveis de ambiente em $ENV_FILE (dry-run)"; stage_done; return
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<EOF
# Variáveis de ambiente das ferramentas instaladas.
# Gerado por instalar_zorin.sh — edite com cuidado.

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

    local marker="# --- instalar-zorin environment ---"
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
    if [ -f "$HOME/.profile" ] && ! grep -qF "$ENV_FILE" "$HOME/.profile"; then
        printf '\n# --- instalar-zorin environment ---\n[ -f "%s" ] && . "%s"\n' \
            "$ENV_FILE" "$ENV_FILE" >> "$HOME/.profile"
        record OK "Carregamento adicionado em $HOME/.profile"
    fi

    # shellcheck disable=SC1090
    . "$ENV_FILE" 2>/dev/null || true
    stage_done
}

install_opencode() {
    begin_stage 12 14 "Ferramentas de desenvolvimento"
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
    stage_done
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

    local channel total="${#DOTNET_CHANNELS[@]}" idx=0
    for channel in "${DOTNET_CHANNELS[@]}"; do
        idx=$((idx + 1))
        if [ -x "$HOME/.dotnet/dotnet" ] && "$HOME/.dotnet/dotnet" --list-sdks 2>/dev/null | grep -q "^${channel}\."; then
            record SKIP ".NET SDK ${channel} (já instalado)"
            draw_bar ".NET SDK" "$idx" "$total"
            continue
        fi
        confirm "Instalar .NET SDK canal ${channel}?" || { record SKIP ".NET ${channel} (recusado)"; draw_bar ".NET SDK" "$idx" "$total"; continue; }
        spinner_start "Instalando .NET SDK ${channel}..."
        run_cmd ".NET SDK ${channel}" "$LOG_DIR/dotnet_${channel}.log" \
            "$installer" --channel "$channel" --install-dir "$HOME/.dotnet"
        draw_bar ".NET SDK" "$idx" "$total"
    done
    info "Para outras versões, use: dotnet-install --channel <versao>"
    info "Liste o instalado com: dotnet --list-sdks"
    stage_done
}

cleanup() {
    begin_stage 13 14 "Limpeza (autoremove/clean)"
    confirm "Executar autoremove e clean?" || { record SKIP "Limpeza (recusada)"; stage_done; return; }
    run_cmd "apt autoremove" "$LOG_DIR/autoremove.log" \
        "${APT_ENV[@]}" "${SUDO[@]}" apt-get autoremove "${APT_OPTS[@]}"
    run_cmd "apt clean" "$LOG_DIR/clean.log" "${SUDO[@]}" apt-get clean
    stage_done
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
            --live-log)       LIVE_LOG=1 ;;
            --no-color)       NO_COLOR=1 ;;
            -v|--verbose)     VERBOSE=1 ;;
            -h|--help)        usage; exit 0 ;;
            *) err "Opção desconhecida: $1"; usage; exit 2 ;;
        esac
        shift
    done
}

start_live_log() {
    # Abre um tail -f do summary e do log da etapa atual numa janela Tilix/terminal.
    [ "$LIVE_LOG" -eq 1 ] || return 0
    [ -t 1 ] || return 0
    have tail || return 0
    info "Live-log: logs em $LOG_DIR"
}

main() {
    parse_args "$@"

    # --no-color deve ser processado antes de definir as cores.
    if [ "$NO_COLOR" -eq 1 ]; then
        C_RESET=""; C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_BOLD=""
        C_DIM=""; C_BAR=""
    fi

    mkdir -p "$LOG_DIR" "$DEB_DIR"
    printf 'Resumo da instalação - %s\n\n' "$(date)" > "$SUMMARY"
    GLOBAL_START_TS="$(date +%s)"

    printf '%s\n' "${C_BOLD}Instalador Zorin OS 18${C_RESET}"
    [ "$DRY_RUN" -eq 1 ] && warn "MODO DRY-RUN: nada será alterado."

    setup_sudo
    ensure_askpass
    setup_sudo

    if [ "$DRY_RUN" -eq 0 ]; then
        prime_sudo || { err "Sem autorização; encerrando."; print_summary; exit 1; }
    fi

    preflight
    [ "$SELF_UPDATE" = "yes" ] && self_update
    start_live_log

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
            install_manual_downloads
            ;;
        *) err "Grupo inválido para --only: $ONLY"; exit 2 ;;
    esac

    print_summary

    local total_elapsed=$(( $(date +%s) - GLOBAL_START_TS ))
    printf '\n%sTempo total: %dm%02ds%s\n' "$C_DIM" \
        $(( total_elapsed / 60 )) $(( total_elapsed % 60 )) "$C_RESET"
}

trap 'spinner_stop' EXIT INT TERM

main "$@"
