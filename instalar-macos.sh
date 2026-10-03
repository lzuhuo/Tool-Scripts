#!/usr/bin/env bash
#
# instalar-macos.sh
# ---------------------------------------------------------------------------
# Provisiona uma máquina macOS (funciona também no Intel x86_64).
#
# Estratégia de instalação (preferência decrescente):
#   1. Download direto de .dmg/.pkg/.zip (sem brew).
#   2. MacPorts (suporte ao Intel) para as ferramentas de linha de comando.
#   3. Ferramentas de desenvolvimento próprias (opencode, nvm, .NET).
#   4. Download manual (modal de navegador) para o que não tem URL estável.
#
# Recursos:
#   - Idempotente: pode ser reexecutado sem quebrar.
#   - Erros reais, contagem de OK/SKIP/FALHA e resumo final.
#   - Logs e cache fora do repositório (~/.local/share/instalar-macos).
#   - Não depende do brew (o Homebrew não suporta mais o Intel x86_64).
#   - Autorização gráfica (prompt de senha nativo do macOS) quando necessário.
#   - Auto-atualização opcional a partir da URL do repositório.
#
# Uso:
#   ./instalar-macos.sh [opções]
#
# Opções:
#   -y, --yes         Não perguntar nada (modo não interativo).
#   -n, --dry-run     Mostra o que faria, sem alterar o sistema.
#   --no-self-update  Não tenta atualizar o script pelo Git.
#   --only <grupo>    Executa só um grupo:
#                     direct|macports|dev|config|manual|cleanup
#   -h, --help        Mostra esta ajuda.
#
# Requisitos: macOS 26, internet, usuário com sudo (para o `sudo installer`
# do MacPorts). Não execute como root.
# ---------------------------------------------------------------------------

set -uo pipefail

# ===========================================================================
# CONFIGURAÇÃO
# ===========================================================================

# --- Arquitetura corrente (Intel x86_64 vs Apple Silicon) -----------------
ARCH="$(uname -m)"

# --- Download direto para apps (sem brew) ----------------------------------
# Apps com URL de download estável. "gh:owner/repo:pattern" resolve o asset
# mais recente de um release do GitHub automaticamente.
# Formato: "Nome|URL|arquivo_local"
# Os URLs são escolhidos pela ABI da máquina (x86_64 / arm64).
DIRECT_DOWNLOADS=()
if [ "$ARCH" = "x86_64" ]; then
    DIRECT_DOWNLOADS=(
        "Visual Studio Code|https://update.code.visualstudio.com/latest/darwin/stable|vscode.zip"
        "DBeaver CE|https://dbeaver.io/files/dbeaver-ce-latest-macos-dmg|dbeaver.dmg"
        "Postman|https://dl.pstmn.io/download/latest/osx_64|postman.zip"
        "Ferdium|gh:ferdium/ferdium-app:x64.dmg|ferdium.dmg"
    )
else
    DIRECT_DOWNLOADS=(
        "Visual Studio Code|https://update.code.visualstudio.com/latest/darwin-arm64/stable|vscode_arm.zip"
        "DBeaver CE|https://dbeaver.io/files/dbeaver-ce-latest-macos-dmg|dbeaver.dmg"
        "Postman|https://dl.pstmn.io/download/latest/osx_arm64|postman_arm.zip"
        "Ferdium|gh:ferdium/ferdium-app:arm64.dmg|ferdium_arm.dmg"
    )
fi

# --- MacPorts (alternativa ao brew para Intel x86_64) ---------------------
# MacPorts tem suporte oficial a macOS 26 Tahoe no Intel (substitui o brew).
MACPORTS_PKG_URL="https://github.com/macports/macports-base/releases/download/v2.12.6/MacPorts-2.12.6-26-Tahoe.pkg"
MACPORTS_CLI=(git wget gh git-lfs)

# --- Ferramentas de desenvolvimento ---------------------------------------
NVM_VERSION="v0.40.8"          # versão do nvm a instalar
NVM_NODE_VERSION="lts"         # versão do Node após o nvm ("" pula)
DOTNET_CHANNELS=(10.0 8.0)   # canais SDK instalados lado a lado em ~/.dotnet

# Arquivo único de variáveis de ambiente, carregado pelo ~/.zprofile e ~/.zshrc.
ENV_FILE="$HOME/.config/instalar-macos/env.sh"

# --- Download manual (modal de navegador) ---------------------------------
# Aplicativos que não têm fórmula/cask mas têm página de download direto.
# Formato: "Nome|URL_da_pagina|padrao_do_arquivo_em_~/Downloads"
MANUAL_APPS=(
    "Zoiper 5|https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/macos"
    "Google Chrome|https://www.google.com/chrome/"
    "Microsoft Edge|https://www.microsoft.com/edge/download"
    "Zoom|https://zoom.us/download"
    "AnyDesk|https://anydesk.com/en/downloads/mac-os"
    "KeePassXC|https://keepassxc.org/download.html"
    "WiFiman Desktop|https://ui.com/download/app/wifiman-desktop/"
    "WinBox|https://mikrotik.com/download/winbox"
    "OpenVPN Connect|https://openvpn.net/client-connect-vpn-for-mac-os/"
)

# --- Auto-atualização do script pelo repositório Git ----------------------
# Deixe vazio para desativar. Exemplo:
#   REPO_RAW_URL="https://raw.githubusercontent.com/usuario/repo/main/instalar-macos.sh"
REPO_RAW_URL=""
SELF_UPDATE="yes"

# --- Caminhos --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
DATA_HOME="$HOME/.local/share/instalar-macos"
CACHE_HOME="$HOME/.cache/instalar-macos"
LOG_DIR="$DATA_HOME/logs"
DL_DIR="$HOME/Downloads"
SUMMARY="$LOG_DIR/summary.log"

# --- Cores -----------------------------------------------------------------
if [ -t 1 ]; then
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
declare -a OK_ITEMS=()

# --- Flags -----------------------------------------------------------------
ASSUME_YES=0
DRY_RUN=0
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
        OK)   OK_COUNT=$((OK_COUNT + 1));     OK_ITEMS+=("$label")
              printf '%s\n' "${C_OK}[OK]${C_RESET}    $label" ;;
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
    else
        # Sem terminal: abre um diálogo nativo de Sim/Não.
        local ans
        ans="$(osascript -e \
            "button returned of (display dialog \"$question\" buttons {\"Não\", \"Sim\"} default button \"Sim\")" 2>/dev/null || echo "Não")"
        [ "$ans" = "Sim" ] && return 0 || return 1
    fi
}

run_cmd() {
    # run_cmd <rótulo> <log> <comando...>
    local label="$1" logfile="$2"; shift 2
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "$label (dry-run): $*"
        return 0
    fi
    mkdir -p "$(dirname "$logfile")"
    if "$@" 2>&1 | tee -a "$logfile"; then
        record OK "$label"; return 0
    fi
    record FAIL "$label (veja $logfile)"; return 1
}

have() { command -v "$1" >/dev/null 2>&1; }

run_spin() {
    # Mesma saída ao vivo na janela (tee -> terminal + log) que run_cmd, para
    # acompanhar passo a passo. Mantém rótulo/registro.
    local label="$1" logfile="$2"; shift 2
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "$label (dry-run): $*"
        return 0
    fi
    mkdir -p "$(dirname "$logfile")"
    if "$@" 2>&1 | tee -a "$logfile"; then
        record OK "$label"; return 0
    fi
    record FAIL "$label (veja $logfile)"; return 1
}

# ===========================================================================
# BREW: resolução de prefixo, arquitetura e sudo
# ===========================================================================

BREW_PREFIX=""

resolve_brew() {
    if have brew; then
        BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    elif [ "$ARCH" = "arm64" ] && [ -x /opt/homebrew/bin/brew ]; then
        BREW_PREFIX="/opt/homebrew"
    elif [ -x /usr/local/bin/brew ]; then
        BREW_PREFIX="/usr/local"
    fi
    if [ -n "$BREW_PREFIX" ] && [ -x "$BREW_PREFIX/bin/brew" ]; then
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    fi
}

ensure_macports() {
    [ -d /opt/local/bin ] && export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    if have port; then
        record OK "MacPorts já instalado ($(port version 2>/dev/null | head -1 || echo '?'))"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Instalação do MacPorts (dry-run)"
        return 0
    fi
    warn "MacPorts não encontrado. Ele precisa de sudo para instalar o .pkg."
    confirm "Instalar o MacPorts agora?" || { record SKIP "MacPorts (recusado)"; return 1; }
    prime_sudo
    local pkg="$CACHE_HOME/macports.pkg"
    if ! curl -fL --retry 3 --progress-bar -o "$pkg" "$MACPORTS_PKG_URL" 2>&1 | tee -a "$LOG_DIR/macports_install.log"; then
        record FAIL "Download do MacPorts (veja $LOG_DIR/macports_install.log)"
        return 1
    fi
    run_spin "Instalando MacPorts" "$LOG_DIR/macports_install.log" sudo installer -pkg "$pkg" -target / || return 1
}

# Autorização "gráfica" (diálogo nativo de senha) para comandos que exigem
# root (ex.: instalador .pkg, softwareupdate). Equivalente ao askpass/zenity
# usado no instalador Ubuntu.
ask_admin() {
    local cmd="$1"
    osascript -e \
        "do shell script \"$cmd\" with administrator privileges" 2>/dev/null
}

# Pede a senha do sudo uma vez e mantém o ticket em cache (quando necessário).
prime_sudo() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    if sudo -n true 2>/dev/null; then
        info "Credencial de sudo já em cache."
        return 0
    fi
    title "Solicitando autorização (senha do sudo)"
    if sudo -v; then
        record OK "Autorização de sudo concedida"
        return 0
    fi
    record FAIL "Falha na autorização do sudo"
    return 1
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

    if [ "$(uname -s)" != "Darwin" ]; then
        err "Este script é exclusivo do macOS."
        exit 1
    fi
    record OK "Sistema: macOS $(sw_vers -productVersion 2>/dev/null || echo '?') ($(uname -m))"

    if [ "$(id -u)" -eq 0 ]; then
        err "Não execute como root; este script usa sudo quando necessário."
        exit 1
    fi

    if xcode-select -p >/dev/null 2>&1; then
        record OK "Xcode Command Line Tools instaladas"
    else
        warn "Xcode CLT ausente — rode 'xcode-select --install' antes de continuar (o MacPorts exige)."
        if have curl || have wget; then record OK "curl/wget disponível"
        else record FAIL "Sem curl/wget para downloads"; fi
    fi

    if have curl || have wget; then record OK "Ferramenta de download disponível"
    else record FAIL "Sem curl/wget para downloads"; exit 1; fi

    resolve_brew
    if have brew; then
        record OK "brew disponível em $BREW_PREFIX"
    else
        record SKIP "brew ainda não instalado"
    fi
}

# ===========================================================================
# ETAPAS
# ===========================================================================

github_latest_asset() {
    local repo="$1" pattern="$2"
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -oE '"browser_download_url": "[^"]+"' \
        | sed -E 's/.*"(https:[^"]+)"/\1/' \
        | grep -E "$pattern" | head -n1
}

direct_install() {
    title "Instalando por download direto (${#DIRECT_DOWNLOADS[@]})"
    # DIRECT_ONLY: se definido, filtra os apps pelo nome (case-sensitive
    # substring). Ex.: DIRECT_ONLY=Postman faz o "direct" tratar só o Postman.
    local entry name url file real_url dest
    for entry in "${DIRECT_DOWNLOADS[@]}"; do
        IFS='|' read -r name url file <<< "$entry"
        if [ -n "${DIRECT_ONLY:-}" ] && [[ "$name" != *"${DIRECT_ONLY}"* ]]; then
            continue
        fi
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$name (dry-run)"; continue
        fi
        real_url="$url"
        if [[ "$url" == gh:* ]]; then
            local ghrepo="${url#gh:}" pattern=""
            if [[ "$ghrepo" == *:* ]]; then
                pattern="${ghrepo##*:}"
                ghrepo="${ghrepo%%:*}"
            fi
            real_url="$(github_latest_asset "$ghrepo" "${pattern:-x64}")"
            [ -z "$real_url" ] && { record FAIL "$name (não foi possível resolver o asset no GitHub)"; continue; }
        fi
        dest="$CACHE_HOME/direct/$file"
        mkdir -p "$CACHE_HOME/direct"
        confirm "Baixar e instalar $name?" || { record SKIP "$name (recusado)"; continue; }
        if [ ! -s "$dest" ]; then
            if ! curl -fL --retry 3 --progress-bar -o "$dest" "$real_url" 2>&1 | tee -a "$LOG_DIR/direct_download.log"; then
                record FAIL "Download $name (veja $LOG_DIR/direct_download.log)"
                continue
            fi
        fi
        install_download "$name" "$dest"
    done
}

macports_install() {
    [ -d /opt/local/bin ] && export PATH="/opt/local/bin:$PATH"
    title "Instalando ferramentas de linha de comando via MacPorts"
    have port || { record FAIL "MacPorts ausente (rode antes '--only macports' para instalar)"; return; }
    local missing=() p
    for p in "${MACPORTS_CLI[@]}"; do
        local installed=0
        if port installed "$p" 2>/dev/null | grep -q '(active)'; then
            installed=1
        fi
        [ "$installed" -eq 0 ] && missing+=("$p")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        record SKIP "CLI via MacPorts (todos já instalados)"; return
    fi
    info "Faltando: ${missing[*]}"
    confirm "Instalar ${#missing[@]} pacote(s) via MacPorts?" || { record SKIP "MacPorts CLI (recusado)"; return; }
    prime_sudo
    run_spin "MacPorts install" "$LOG_DIR/macports_ports.log" sudo port install "${missing[@]}"
}

# --- Variáveis de ambiente -------------------------------------------------
setup_shell_env() {
    title "Configurando variáveis de ambiente do shell"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Variáveis de shell em $ENV_FILE (dry-run)"; return
    fi

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" <<EOF
# Variáveis de ambiente das ferramentas instaladas.
# Gerado por instalar-macos.sh — edite com cuidado.

# Binários do usuário (wrapper screencapture, ferramentas avulsas)
export PATH="\$HOME/.local/bin:\$PATH"

# MacPorts (ferramentas de linha instaladas por --only macports)
export PATH="/opt/local/bin:/opt/local/sbin:\$PATH"

# opencode
export PATH="\$HOME/.opencode/bin:\$PATH"

# nvm (Node Version Manager)
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"

# .NET SDK
export DOTNET_ROOT="\$HOME/.dotnet"
export PATH="\$PATH:\$DOTNET_ROOT:\$DOTNET_ROOT/tools"
EOF
    record OK "Arquivo de ambiente criado: $ENV_FILE"

    local marker="# --- instalar-macos environment ---"
    local load_line="[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\""
    local rc
    for rc in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -e "$rc" ]; then
            if ! grep -qF "$marker" "$rc" 2>/dev/null; then
                { printf '\n%s\n%s\n' "$marker" "$load_line"; } >> "$rc"
                record OK "Carregamento adicionado em $rc"
            else
                record SKIP "Carregamento já presente em $rc"
            fi
        fi
    done

    # shellcheck disable=SC1090
    . "$ENV_FILE" 2>/dev/null || true
}

# Wrapper `screencapture` em ~/.local/bin (substitui o flameshot, que é só
# Linux). expõe o utilitário nativo com flags úteis.
setup_screencapture() {
    title "Wrapper de captura de tela"
    if [ "$DRY_RUN" -eq 1 ]; then
        record SKIP "Wrapper screencapture (dry-run)"; return
    fi
    local target="$HOME/.local/bin/screenshot"
    mkdir -p "$HOME/.local/bin"
    if [ -x "$target" ]; then
        record SKIP "screenshot (já existe)"; return
    fi
    cat > "$target" <<'EOS'
#!/usr/bin/env bash
# screenshot — captura de tela no macOS (substitui o flameshot, que é Linux-only).
# Uso:
#   screenshot              abre a UI interativa (área/janela/menu)
#   screenshot -s           seleciona uma área
#   screenshot -w           captura uma janela
#   screenshot -l <id>      captura uma janela pelo window id
#   screenshot arquivo.png  grava em caminho específico
if [ "$#" -eq 0 ]; then set -- -i; fi
exec /usr/sbin/screencapture "$@"
EOS
    chmod +x "$target"
    record OK "Wrapper criado em $target"
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
    run_spin "opencode" "$LOG_DIR/opencode.log" \
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
            run_spin "nvm" "$LOG_DIR/nvm.log" bash -c \
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
        [ "$node_arg" = "--lts" ] && node_label="lts"
        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "Node ${node_label} via nvm (dry-run)"
        elif nvm ls "$node_label" >/dev/null 2>&1 && [ "$node_arg" != "--lts" ]; then
            record SKIP "Node ${node_label} (já instalado via nvm)"
        else
            run_spin "Node ${node_label} (nvm install)" "$LOG_DIR/nvm_node.log" \
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
    confirm "Instalar .NET SDK (${DOTNET_CHANNELS[*]}) em ~/.dotnet?" || { record SKIP ".NET (recusado)"; return; }

    local installer="$CACHE_HOME/dotnet-install.sh"
    mkdir -p "$CACHE_HOME"
    if [ ! -s "$installer" ]; then
        curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer" \
            >>"$LOG_DIR/dotnet.log" 2>&1 \
            || { record FAIL ".NET (falha ao baixar dotnet-install.sh)"; return; }
        chmod +x "$installer"
    fi
    # Disponibiliza o helper como o comando "dotnet-install" no PATH.
    if [ ! -x "$HOME/.local/bin/dotnet-install" ]; then
        mkdir -p "$HOME/.local/bin"
        install -m 0755 "$installer" "$HOME/.local/bin/dotnet-install"
        record OK "Comando dotnet-install em ~/.local/bin"
    fi

    mkdir -p "$HOME/.dotnet"
    local channel
    for channel in "${DOTNET_CHANNELS[@]}"; do
        if [ -x "$HOME/.dotnet/dotnet" ] && "$HOME/.dotnet/dotnet" --list-sdks 2>/dev/null | grep -q "^${channel}\."; then
            record SKIP ".NET SDK ${channel} (já instalado)"
            continue
        fi
        run_spin ".NET SDK ${channel}" "$LOG_DIR/dotnet_${channel}.log" \
            "$installer" --channel "$channel" --install-dir "$HOME/.dotnet"
    done
    info "Para outras versões, use: dotnet-install --channel <versao>"
    info "Liste o instalado com: dotnet --list-sdks"
}

# --- Download manual + instalação -----------------------------------------
filesize() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

# Detecta se existe um app correspondente à chave (normalização parecida com
# a detecção de arquivos: só letras, UPPER, sem espaços/pontuação).
_app_installed() {
    local key="$1"
    [ -z "$key" ] && return 1
    find /Applications /System/Applications -maxdepth 2 -name '*.app' 2>/dev/null \
      | while IFS= read -r app; do
          local n
          n="$(basename "$app" | tr -d '[:punct:][:space:]' | tr '[:lower:]' '[:upper:]')"
          case "$n" in *"$key"*) echo "x"; break ;; esac
        done | grep -q .
}

manual_downloads() {
    [ "${#MANUAL_APPS[@]}" -eq 0 ] && return
    title "Downloads manuais (modal de navegador)"
    local entry name url
    for entry in "${MANUAL_APPS[@]}"; do
        IFS='|' read -r name url <<< "$entry"

        if [ "$DRY_RUN" -eq 1 ]; then
            record SKIP "$name (dry-run): modal em $url"; continue
        fi

        # Chave derivada do nome do app (case-insensitive, sem separadores).
        local app_key
        app_key="$(printf '%s' "$name" | cut -d' ' -f1 | tr -d '[:punct:]' | tr '[:lower:]' '[:upper:]')"

        # Se o app já está instalado, pula (não abre navegador).
        if _app_installed "$app_key"; then
            record SKIP "$name (já instalado)"
            continue
        fi

        confirm "Abrir o navegador para baixar $name agora?" || { record SKIP "$name (recusado)"; continue; }
        mkdir -p "$DL_DIR"
        info "Abrindo a página de download de $name."
        info "Salve o arquivo no navegador; o script detecta pelo nome do programa (case-insensitive, sem separadores)."

        open "$url" >>"$LOG_DIR/manual.log" 2>&1 || true

        local found="" waited=0
        while [ "$waited" -lt 900 ]; do
            local candidate="" f2
            while IFS= read -r -d '' f2; do
                # normaliza o nome do arquivo: só letras/hex/dígitos UPPER
                local fk
                fk="$(basename "$f2" | tr -d '[:punct:][:space:]' | tr '[:lower:]' '[:upper:]')"
                if [[ "$fk" == *"${app_key}"* ]]; then candidate="$f2"; break; fi
            done < <(
                find "$DL_DIR" -maxdepth 1 -type f \
                    \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.zip' \) \
                    ! -iname '*.crdownload' ! -iname '*.download' \
                    -mmin -10 2>/dev/null -print0
            )
            if [ -n "$candidate" ] && [ -s "$candidate" ]; then
                local s1 s2
                s1="$(filesize "$candidate")"; sleep 2
                s2="$(filesize "$candidate")"
                if [ "$s1" = "$s2" ] && [ "$s1" -gt 0 ]; then
                    found="$candidate"; break
                fi
            else
                if [ $((waited % 20)) -eq 0 ]; then
                    info "Aguardando o arquivo '${app_key}*' (download de $name) em $DL_DIR (${waited}s) ..."
                fi
            fi
            sleep 2; waited=$((waited + 2))
        done

        if [ -z "$found" ] || [ ! -s "$found" ]; then
            record FAIL "$name (download não detectado em $DL_DIR)"
            continue
        fi
        install_download "$name" "$found" || record FAIL "$name (instalação falhou)"
    done
}

install_download() {
    # install_download <nome> <arquivo>
    local name="$1" f="$2"
    case "$f" in
        *.zip)
            confirm "Extrair e instalar $name (.zip)?" || { record SKIP "$name (recusado)"; return 0; }
            if [ "$DRY_RUN" -eq 1 ]; then record SKIP "$name .zip (dry-run)"; return 0; fi
            local exdir; exdir="$(mktemp -d)"
            if unzip -q "$f" -d "$exdir" 2>>"$LOG_DIR/manual.log"; then
                local app
                app="$(find "$exdir" -maxdepth 4 -type d -name '*.app' \
                        -not -path '*/__MACOSX/*' | head -n1)"
                if [ -n "$app" ]; then
                    local target="/Applications/$(basename "$app")"
                    [ -e "$target" ] && rm -rf "$target"
                    cp -R "$app" /Applications/ && record OK "$name copiado para /Applications"
                else
                    record FAIL "$name (nenhum .app encontrado no .zip)"
                fi
            else
                record FAIL "$name (não foi possível extrair o .zip)"
            fi
            rm -rf "$exdir"
            ;;
        *.pkg)
            confirm "Instalar $name via .pkg (precisa de senha)?" || { record SKIP "$name (recusado)"; return 0; }
            if [ "$DRY_RUN" -eq 1 ]; then record SKIP "$name .pkg (dry-run)"; return 0; fi
            if ask_admin "installer -pkg '$f' -target /" >>"$LOG_DIR/manual.log" 2>&1; then
                record OK "$name instalado (.pkg)"
            else
                record FAIL "$name (falha ao instalar o .pkg)"
            fi
            ;;
        *.dmg)
            confirm "Montar e instalar $name (.dmg)?" || { record SKIP "$name (recusado)"; return 0; }
            if [ "$DRY_RUN" -eq 1 ]; then record SKIP "$name .dmg (dry-run)"; return 0; fi
            local mount_point
            mount_point="$(hdiutil attach -nobrowse "$f" 2>/dev/null \
                | grep '/Volumes/' | head -n1 \
                | awk -F'\t' '{print $NF}')"
            if [ -z "$mount_point" ] || [ ! -d "$mount_point" ]; then
                record FAIL "$name (não foi possível montar o .dmg)"
                return 1
            fi
            local app
            app="$(find "$mount_point" -maxdepth 2 -name '*.app' | head -n1)"
            if [ -n "$app" ]; then
                local target="/Applications/$(basename "$app")"
                [ -e "$target" ] && rm -rf "$target"
                cp -R "$app" /Applications/ && record OK "$name copiado para /Applications"
            else
                record FAIL "$name (nenhum .app encontrado no .dmg)"
            fi
            hdiutil detach -quiet "$mount_point" >/dev/null 2>&1 || true
            ;;
        *)
            record SKIP "$name (formato não automático: $f — instale manualmente)"
            ;;
    esac
}

# --- Limpeza ---------------------------------------------------------------
cleanup() {
    title "Limpeza"
    confirm "Limpar cache de downloads diretos?" || { record SKIP "Limpeza (recusada)"; return; }
    if [ -d "$CACHE_HOME/direct" ]; then
        rm -rf "$CACHE_HOME/direct"
        record OK "Cache de downloads diretos removido"
    else
        record SKIP "Nenhum cache de download para limpar"
    fi
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
    if [ "$OK_COUNT" -gt 0 ]; then
        info "Feito/verificado nesta execução:"
        local it
        for it in "${OK_ITEMS[@]}"; do printf '  - %s\n' "$it"; done
    fi
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
    mkdir -p "$LOG_DIR" "$CACHE_HOME" "$DL_DIR"
    printf 'Resumo da instalação - %s\n\n' "$(date)" > "$SUMMARY"

    printf '%s\n' "${C_BOLD}Instalador macOS${C_RESET}"
    [ "$DRY_RUN" -eq 1 ] && warn "MODO DRY-RUN: nada será alterado."

    preflight

    # MacPorts é o pré-requisito (alternativo ao brew) para os CLI;
    # os demais grupos não precisam dele e não forçam o install.
    case "$ONLY" in
        macports|"")
            ensure_macports || { print_summary; exit 1; }
            ;;
        *) ;;
    esac
    [ "$SELF_UPDATE" = "yes" ] && self_update

    case "$ONLY" in
        direct)   direct_install ;;
        macports) macports_install ;;
        dev)      setup_shell_env; setup_screencapture; install_opencode; install_nvm; install_dotnet ;;
        config)   setup_shell_env; setup_screencapture ;;
        manual)   manual_downloads ;;
        cleanup)  cleanup ;;
        "")
            direct_install
            macports_install
            setup_shell_env
            setup_screencapture
            install_opencode
            install_nvm
            install_dotnet
            cleanup
            # Por último: depende da interação manual do usuário.
            # Em modo -y (não interativo) não executa para não ficar esperando
            # downloads no navegador; rode depois com --only manual.
            if [ "$ASSUME_YES" -eq 0 ]; then
                manual_downloads
            else
                record SKIP "manual (-y): pulado; rode depois com --only manual"
            fi
            ;;
        *) err "Grupo inválido para --only: $ONLY"; exit 2 ;;
    esac

    print_summary
}

main "$@"
