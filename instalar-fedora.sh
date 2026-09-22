#!/usr/bin/env bash

set -Eeuo pipefail

readonly DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/instalar-fedora.XXXXXX")"
readonly FEDORA_PACKAGES=(
    tilix
    flameshot
    git
    curl
    wget
    gnome-tweaks
    gnome-browser-connector
    flatpak
    keepassxc
)

cleanup() {
    rm -rf -- "$DOWNLOAD_DIR"
}
trap cleanup EXIT

die() {
    printf 'ERRO: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "comando não encontrado: $1"
}

download_rpm() {
    local url="$1"
    local output="$2"

    printf 'Baixando %s\n' "$output"
    curl --fail --location --retry 3 --retry-delay 2 --silent --show-error \
        --output "$DOWNLOAD_DIR/$output" "$url"

    # Evita tentar instalar uma página de erro ou uma página de download.
    rpm -qip "$DOWNLOAD_DIR/$output" >/dev/null 2>&1 ||
        die "o download não parece ser um RPM válido: $url"
}

require_command curl
require_command rpm
require_command sudo

[[ -r /etc/os-release ]] || die "não foi possível identificar o sistema operacional"
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "fedora" ]] ||
    die "este script foi feito para Fedora; sistema detectado: ${PRETTY_NAME:-desconhecido}"

[[ "$(uname -m)" == "x86_64" ]] ||
    die "os RPMs de terceiros deste script exigem arquitetura x86_64"

printf 'Atualizando metadados e pacotes do Fedora...\n'
sudo dnf upgrade --refresh -y
sudo dnf install -y "${FEDORA_PACKAGES[@]}"

printf 'Habilitando o Flathub...\n'
flatpak remote-add --if-not-exists \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo

printf 'Configurando repositórios oficiais de aplicativos RPM...\n'

# Visual Studio Code: repositório RPM oficial da Microsoft.
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Google Chrome: o RPM oficial instala também o repositório de atualização.
sudo dnf install -y \
    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

# Microsoft Edge: repositório RPM oficial da Microsoft.
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo tee /etc/yum.repos.d/microsoft-edge.repo >/dev/null <<'EOF'
[microsoft-edge]
name=Microsoft Edge
baseurl=https://packages.microsoft.com/yumrepos/edge
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf install -y code google-chrome-stable microsoft-edge-stable

printf 'Baixando RPMs oficiais sem repositório...\n'

# Os links abaixo são mantidos pelos próprios fornecedores. A validação rpm -qip
# impede que uma página HTML seja tratada como pacote.
download_rpm \
    'https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-rpm' \
    'zoiper.rpm'
download_rpm \
    'https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.15.1-Linux-x64.rpm' \
    'vnc-viewer.rpm'
download_rpm \
    'https://zoom.us/client/latest/zoom_x86_64.rpm' \
    'zoom.rpm'

sudo dnf install -y "$DOWNLOAD_DIR"/*.rpm

printf 'Instalando aplicativos do Flathub...\n'
readonly FLATPAK_APPS=(
    com.mattjakeman.ExtensionManager
    com.getpostman.Postman
    com.mikrotik.WinBox
    org.freedownloadmanager.Manager
    io.dbeaver.DBeaverCommunity
    com.anydesk.Anydesk
    org.ferdium.Ferdium
)
flatpak install --user --or-update -y flathub "${FLATPAK_APPS[@]}"

printf '\nInstalação concluída.\n'
