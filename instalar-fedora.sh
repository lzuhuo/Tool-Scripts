#!/bin/bash

# Atualização de Pacotes
# No Fedora, o dnf check-update substitui o apt update
sudo dnf upgrade -y

# Instalação de Programas via repositório oficial
# Note as mudanças: gnome-tweaks (igual), chrome-gnome-shell -> gnome-browser-connector
sudo dnf install tilix flameshot git curl gnome-tweaks gnome-browser-connector flatpak -y

# Adicionando suporte ao Flathub
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Download de Programas (Versões RPM)
mkdir -p ~/programas
cd ~/programas

# Observação: Alguns links diretos de .deb foram alterados para a página ou versão .rpm equivalente
# Zoiper (O link direto pode variar, o ideal é baixar o tar.xz ou rpm do site)
wget https://www.zoiper.com/en/voip-softphone/download/zoiper5/for/linux-rpm -O zoiper.rpm

# VNC Viewer
wget https://downloads.realvnc.com/download/file/viewer.files/VNC-Viewer-7.15.1-Linux-x64.rpm

# Azure Data Studio
wget https://go.microsoft.com/fwlink/?linkid=2273151 -O azuredatastudio.rpm

# WiFiman (Ubiquiti não fornece RPM oficial estável as vezes, recomendável verificar se há flatpak)
# Se houver apenas .deb, o alien poderia converter, mas aqui buscamos o nativo:
# wget [link-do-rpm-se-disponivel]

# Instalação de Programas baixados
# O dnf instala arquivos locais e resolve dependências simultaneamente
sudo dnf localinstall *.rpm -y

cd ..

# Instalação de aplicativos Flatpak
# Mantendo a lista original
flatpak install flathub com.mattjakeman.ExtensionManager -y
flatpak install flathub com.getpostman.Postman -y
flatpak install flathub com.mikrotik.WinBox -y
flatpak install flathub org.keepassxc.KeePassXC -y
flatpak install flathub us.zoom.Zoom -y
flatpak install flathub com.google.Chrome -y
flatpak install flathub org.freedownloadmanager.Manager -y
flatpak install flathub com.microsoft.Edge -y
flatpak install flathub io.dbeaver.DBeaverCommunity -y
flatpak install flathub com.anydesk.Anydesk -y
flatpak install flathub org.ferdium.Ferdium -y
flatpak install flathub com.visualstudio.code -y

# Limpeza Final
sudo rm -rf ~/programas
sudo dnf autoremove -y
sudo dnf clean all

echo "Instalação concluída com sucesso!"
