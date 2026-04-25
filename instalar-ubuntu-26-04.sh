#!/bin/bash

# Diretório base (onde está o script)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEB_DIR="$SCRIPT_DIR/deb_packages"
LOG_DIR="$SCRIPT_DIR/install_logs"
SUMMARY="$LOG_DIR/summary.log"

mkdir -p "$DEB_DIR" "$LOG_DIR"
echo "Resumo da instalação - $(date)" > "$SUMMARY"

# Função para verificar status
check_status() {
    if [ $1 -eq 0 ]; then
        echo "[OK] $2" | tee -a "$SUMMARY"
    else
        echo "[ERRO] $2" | tee -a "$SUMMARY"
    fi
}

# Atualização de pacotes
sudo apt update >> "$LOG_DIR/apt_update.log" 2>&1
check_status $? "Atualização de pacotes"

sudo apt upgrade -y >> "$LOG_DIR/apt_upgrade.log" 2>&1
check_status $? "Upgrade de pacotes"

# Instalação de pacotes oficiais
sudo apt install -y tilix flameshot git curl gnome-tweaks gnome-browser-connector flatpak wget >> "$LOG_DIR/apt_install.log" 2>&1
check_status $? "Instalação de pacotes oficiais"

# Configuração do Flathub
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$LOG_DIR/flatpak_remote.log" 2>&1
check_status $? "Configuração do Flathub"

# Download de pacotes .deb (apenas se não existirem)
if [ ! -f "$DEB_DIR/vncviewer.deb" ]; then
    wget -O "$DEB_DIR/vncviewer.deb" "https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.15.1-Linux-x64.deb" >> "$LOG_DIR/vnc_download.log" 2>&1
    check_status $? "Download VNC Viewer"
else
    echo "[SKIP] VNC Viewer já presente em $DEB_DIR" | tee -a "$SUMMARY"
fi

if [ ! -f "$DEB_DIR/azuredatastudio.deb" ]; then
    wget -O "$DEB_DIR/azuredatastudio.deb" "https://go.microsoft.com/fwlink/?linkid=2272920" >> "$LOG_DIR/azureds_download.log" 2>&1
    check_status $? "Download Azure Data Studio"
else
    echo "[SKIP] Azure Data Studio já presente em $DEB_DIR" | tee -a "$SUMMARY"
fi

# Instalação de pacotes .deb
if ls "$DEB_DIR"/*.deb 1> /dev/null 2>&1; then
    sudo apt install "$DEB_DIR"/*.deb -y >> "$LOG_DIR/deb_install.log" 2>&1
    sudo apt install -f
    check_status $? "Instalação de pacotes .deb"
else
    echo "[AVISO] Nenhum pacote .deb encontrado em $DEB_DIR" | tee -a "$SUMMARY"
fi

# Instalação de aplicativos Flatpak
for app in \
    com.mattjakeman.ExtensionManager \
    com.getpostman.Postman \
    com.mikrotik.WinBox \
    org.keepassxc.KeePassXC \
    us.zoom.Zoom \
    com.google.Chrome \
    org.freedownloadmanager.Manager \
    com.microsoft.Edge \
    io.dbeaver.DBeaverCommunity \
    com.anydesk.Anydesk \
    org.ferdium.Ferdium \
    com.visualstudio.code
do
    flatpak install flathub $app -y >> "$LOG_DIR/flatpak_$app.log" 2>&1
    check_status $? "Flatpak $app"
done

# Limpeza final
sudo apt autoremove -y >> "$LOG_DIR/autoremove.log" 2>&1
check_status $? "Autoremove"

sudo apt clean >> "$LOG_DIR/clean.log" 2>&1
check_status $? "Limpeza apt"

echo "Instalação concluída! Veja o resumo em $SUMMARY"

